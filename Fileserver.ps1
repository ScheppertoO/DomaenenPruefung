<# Provision the physical disk for the fileserver (Windows Gen2, GPT, Basic)
$driveLetter = 'E'
# Find a disk that is online and not yet initialized
$disk = Get-Disk | Where-Object { $_.IsOffline -eq $false -and $_.PartitionStyle -eq 'RAW' } | Select-Object -First 1
if ($disk) {
    Write-Host "Initializing Disk Number $($disk.Number) as GPT..."
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false

    Write-Host "Creating new partition using maximum available space..."
    $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter -Confirm:$false

    Write-Host "Formatting partition as NTFS and labeling it 'Firmendaten'..."
    Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "Firmendaten" -Confirm:$false

    Write-Host "Assigning drive letter $driveLetter to the new partition..."
    Set-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -NewDriveLetter $driveLetter

    Write-Host "Disk provisioned and available as drive $driveLetter:"
}
else {
    Write-Host "No suitable uninitialized disk found for provisioning."
}
#>

# Define folder paths
$basePath = "E:\Firmendaten"
$homePath = "E:\Home"
$folders = @(
    "$basePath",
    "$basePath\Gefue-Daten",
    "$basePath\Vertrieb-Daten",
    "$basePath\Versand-Daten",
    $homePath
)

# Create folder structure
foreach ($folder in $folders) {
    if (-not (Test-Path -Path $folder)) {
        New-Item -Path $folder -ItemType Directory | Out-Null
        Write-Host "Created folder: $folder"
    } else {
        Write-Host "Folder already exists: $folder"
    }
}

# Set permissions
$acl = Get-Acl $basePath
$acl.SetAccessRuleProtection($true, $false) # Disable inheritance
Set-Acl -Path $basePath -AclObject $acl

# Restrict domain users from creating folders in Firmendaten
$domainUsers = "DOMAIN\Domain Users"
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($domainUsers, "CreateFolders", "Deny")))
Set-Acl -Path $basePath -AclObject $acl

# Assign specific permissions
$permissions = @(
    @{Path="$basePath\Gefue-Daten"; User="DOMAIN\Olaf.Oben"; Access="Modify"},
    @{Path="$basePath\Vertrieb-Daten"; User="DOMAIN\Max.Mitte"; Access="Modify"},
    @{Path="$basePath\Versand-Daten"; User="DOMAIN\Ute.Unten"; Access="Read"},
    @{Path="$basePath\Versand-Daten"; User="DOMAIN\Geschaeftsfuehrer"; Access="Modify"}
)

foreach ($perm in $permissions) {
    $acl = Get-Acl $perm.Path
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($perm.User, $perm.Access, "Allow")))
    Set-Acl -Path $perm.Path -AclObject $acl
    Write-Host "Set $($perm.Access) permission for $($perm.User) on $($perm.Path)"
}

# Enable access-based enumeration
Import-Module ServerManager
Install-WindowsFeature FS-Resource-Manager
Set-SmbShare -Name "Firmendaten" -FolderEnumerationMode AccessBased

# Configure drive mappings
$users = @("Olaf", "Max", "Ute")
foreach ($user in $users) {
    New-PSDrive -Name "H" -PSProvider FileSystem -Root $homePath -Persist -Scope Global -Credential (Get-Credential "DOMAIN\$user")
    Write-Host "Mapped H: drive for $user"
}

New-PSDrive -Name "X" -PSProvider FileSystem -Root $basePath -Persist -Scope Global
Write-Host "Mapped X: drive for all users"
