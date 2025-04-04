# Benutzerabfrage für den Servernamen
$serverName = Read-Host "Bitte geben Sie den Servernamen des Fileservers ein"

# Benutzerinformationen
$users = @(
    @{Name="Ute Unten"; DepartmentPath="Firmendaten\Versand-Daten"},
    @{Name="Max Mitte"; DepartmentPath="Firmendaten\Vertrieb-Daten"},
    @{Name="Olaf Oben"; DepartmentPath="Firmendaten\Gefue-Daten"}
)

# Pfad für die Logonskripte
$logonScriptPath = "c:\Users\kd\OneDrive - Diamant Software GmbH\Dokumente\GitHub\ToolV2\DomaenenPruefung\Logonscripte"

# Logonskripte generieren
foreach ($user in $users) {
    $batFileName = "$logonScriptPath\$($user.Name -replace ' ', '')-Logon.bat"
    $batContent = @"
@echo off
:: Logon Script für $($user.Name)

:: Home-Verzeichnis einbinden
net use H: \\$serverName\Home 

:: Abteilungs-Verzeichnis einbinden
net use X: \\$serverName\$($user.DepartmentPath)
"@
    # Speichern der .bat-Datei
    $batContent | Set-Content -Path $batFileName -Encoding UTF8
    Write-Host "Logonskript erstellt: $batFileName"
}

# Define folder paths
$basePath = "E:\Firmendaten"
$homePath = "E:\Home"
$folders = @(
    "$basePath",
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

# Set permissions
$acl = Get-Acl $basePath
$acl.SetAccessRuleProtection($true, $false) # Disable inheritance
Set-Acl -Path $basePath -AclObject $acl

# Restrict domain users from creating folders in Firmendaten
$domainPrefix = "Technotrans"  # Domain name for your environment
$domainUsers = "$domainPrefix\Domain Users"
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($domainUsers, "CreateFolders", "Deny")))
Set-Acl -Path $basePath -AclObject $acl

# Assign permissions to DL groups instead of directly to users
$permissions = @(
    # Gefue permissions
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-L"; Access="ReadAndExecute", "Allow"},
    
    # Vertrieb permissions
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-L"; Access="ReadAndExecute", "Allow"},
    
    # Versand permissions
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-L"; Access="ReadAndExecute", "Allow"},
    
    # Shared permissions for all AE groups
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Gefue-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Versand-Daten-AE"; Access="Modify"}
)

foreach ($perm in $permissions) {
    $acl = Get-Acl $perm.Path
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($perm.User, $perm.Access, "ContainerInherit, ObjectInherit", "None", "Allow")))
    Set-Acl -Path $perm.Path -AclObject $acl
    Write-Host "Set $($perm.Access) permission for $($perm.User) on $($perm.Path)"
}

# Netzwerkfreigaben erstellen
foreach ($folder in $folders) {
    $shareName = ($folder -replace "E:\\Firmendaten\\", "").TrimEnd("-Daten")
    if ($shareName -ne "") {
        New-SmbShare -Name "$shareName-Daten" -Path $folder -FullAccess "$serverName\$shareName-Daten-AE"
        Write-Host "Netzwerkfreigabe erstellt: $shareName-Daten"
    }
}
