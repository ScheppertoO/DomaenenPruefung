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
