# Dynamisch den Domainnamen und den Servernamen ermitteln
$domainPrefix = $env:USERDOMAIN
$serverName = $env:COMPUTERNAME

# Define folder paths
$basePath = "E:\Firmendaten"
$homePath = "E:\Home"
$folders = @(
    $basePath,
    "$basePath\Gefue-Daten",
    "$basePath\Vertrieb-Daten",
    "$basePath\Versand-Daten",
    "$basePath\Shared-Daten",
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

# Set permissions on base folder: Deaktiviere Vererbung
$acl = Get-Acl $basePath
$acl.SetAccessRuleProtection($true, $false) # Deaktiviert die Vererbung
Set-Acl -Path $basePath -AclObject $acl

# Restrict domain users from creating directories in Firmendaten
# Hier wird die Gruppe "Domain Users" dynamisch mit dem korrekten Domainnamen aufgebaut
$domainUsers = "$domainPrefix\Domain Users"
$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $domainUsers,
    "CreateDirectories",
    [System.Security.AccessControl.InheritanceFlags]::None,
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Deny
)
try {
    $acl.AddAccessRule($denyRule)
    Set-Acl -Path $basePath -AclObject $acl
} catch {
        Write-Host "Fehler beim Hinzufügen der Deny-Regel für $($domainUsers): $($_.Exception.Message)"
}



# Assign permissions to DL-Gruppen
$permissions = @(
    # Gefue-Daten
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\SYSTEM"; Access="FullControl"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\BUILTIN\Administrators"; Access="FullControl"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\Domain Admins"; Access="FullControl"},

    # Vertrieb-Daten
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\SYSTEM"; Access="FullControl"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\BUILTIN\Administrators"; Access="FullControl"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\Domain Admins"; Access="FullControl"},
    
    # Versand-Daten
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\SYSTEM"; Access="FullControl"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\BUILTIN\Administrators"; Access="FullControl"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\Domain Admins"; Access="FullControl"},
    
    # Shared-Daten
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Shared-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Shared-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\SYSTEM"; Access="FullControl"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\BUILTIN\Administrators"; Access="FullControl"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\Domain Admins"; Access="FullControl"}
)

foreach ($perm in $permissions) {
    $acl = Get-Acl $perm.Path
    $inheritFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
                     [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $perm.User,
        $perm.Access,
        $inheritFlags,
        $propagationFlags,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    try {
        $acl.AddAccessRule($accessRule)
    } catch {
        Write-Warning "Skipping AddAccessRule for $($perm.User) on $($perm.Path): $($_.Exception.Message)"
    }
    Set-Acl -Path $perm.Path -AclObject $acl
    Write-Host "Set $($perm.Access) permission for $($perm.User) on $($perm.Path)"
}

# Erstelle SMB-Freigaben für die Unterordner in Firmendaten (ohne $basePath und $homePath)
$baseSubFolders = @(
    "$basePath\Gefue-Daten",
    "$basePath\Vertrieb-Daten",
    "$basePath\Versand-Daten",
    "$basePath\Shared-Daten"
)

foreach ($folder in $baseSubFolders) {
    # Nutzt den Ordnernamen als Share-Namen
    $shareName = Split-Path $folder -Leaf
    # Anstatt den Servernamen zu verwenden, wird hier die Domaingruppe verwendet
    $fullAccessAccount = "$domainPrefix\DL-$shareName-AE"
    if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        try {
            New-SmbShare -Name $shareName -Path $folder -FullAccess $fullAccessAccount
            Write-Host "Netzwerkfreigabe erstellt: $shareName"
        } catch {
            Write-Host "Fehler beim Erstellen der Freigabe für $folder: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Share $shareName existiert bereits, keine Aktion erforderlich."
    }
}



