Import-Module ActiveDirectory -ErrorAction Stop

# Überprüfen, ob das Skript mit Administratorrechten ausgeführt wird
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Das Skript muss mit Administratorrechten ausgeführt werden!"
    Write-Warning "Bitte starten Sie PowerShell als Administrator und führen Sie das Skript erneut aus."
    exit
}

# Dynamisch den Domainnamen und den Servernamen ermitteln
$domainPrefix = $env:USERDOMAIN

# Define folder paths
$basePath = "E:\Firmendaten"
$homePath = "E:\Home"
$folders = @(
    $basePath,
    "$basePath\Gefue-Daten",
    "$basePath\Vertrieb-Daten",
    "$basePath\Versand-Daten",
    "$basePath\Shared-Daten"
    <#$homePath,
    "$homePath\Olaf.Oben",  # Fixed: Corrected capitalization from $homepath to $homePath
    "$homePath\Ute.Unten",  # Fixed: Corrected capitalization from $homepath to $homePath
    "$homePath\Max.Mitte"   # Fixed: Corrected capitalization from $homepath to $homePath #>
)

# Create folder structure
foreach ($folder in $folders) {
    # Skip the home root folder but create all other folders
    if ($folder -eq $homePath) {
        # Make sure home folder exists since we need to create user folders in it
        if (-not (Test-Path -Path $folder)) {
            New-Item -Path $folder -ItemType Directory | Out-Null
            Write-Host "Created required home folder: $folder"
        } else {
            Write-Host "Home folder already exists: $folder"
        }
        continue
    }
    
    if (-not (Test-Path -Path $folder)) {
        New-Item -Path $folder -ItemType Directory | Out-Null
        Write-Host "Created folder: $folder"
    } else {
        Write-Host "Folder already exists: $folder"
    }
}

# Helper function to resolve security principals
function Test-SecurityPrincipal {
    param(
        [string]$Name
    )
    
    try {
        $ntAccount = New-Object System.Security.Principal.NTAccount($Name)
        $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
        return @{Success=$true; Account=$ntAccount; SID=$sid}
    } catch {
        return @{Success=$false; Error=$_.Exception.Message; Account=$Name}
    }
}

# Function to get SID from well-known identifiers
function Get-WellKnownSID {
    param(
        [string]$WellKnownName
    )

    $wellKnownSIDs = @{
        'Administrators' = 'S-1-5-32-544'
        'System' = 'S-1-5-18'
        'Everyone' = 'S-1-1-0'
    }

    if ($wellKnownSIDs.ContainsKey($WellKnownName)) {
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier($wellKnownSIDs[$WellKnownName])
            return @{Success=$true; SID=$sid}
        } catch {
            return @{Success=$false; Error=$_.Exception.Message}
        }
    }
    
    return @{Success=$false; Error="Unknown well-known SID name"}
}

# Function to get domain SID
function Get-DomainSID {
    try {
        # Try to get current user's domain SID
        $currentUserSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        if ($currentUserSID) {
            $domainSIDString = $currentUserSID.Value.Substring(0, $currentUserSID.Value.LastIndexOf("-"))
            return @{Success=$true; DomainSID=$domainSIDString}
        }
    } catch {
        Write-Warning "Could not get domain SID: $($_.Exception.Message)"
    }
    return @{Success=$false; Error="Could not determine domain SID"}
}

# Function to get a domain role SID
function Get-DomainRoleSID {
    param(
        [string]$RoleName
    )
    
    $wellKnownRoles = @{
        'DomainAdmins' = '512'
        'DomainUsers' = '513'
    }
    
    if ($wellKnownRoles.ContainsKey($RoleName)) {
        $domainInfo = Get-DomainSID
        if ($domainInfo.Success) {
            $roleSID = "$($domainInfo.DomainSID)-$($wellKnownRoles[$RoleName])"
            try {
                $sid = New-Object System.Security.Principal.SecurityIdentifier($roleSID)
                return @{Success=$true; SID=$sid}
            } catch {
                return @{Success=$false; Error=$_.Exception.Message}
            }
        } else {
            return $domainInfo
        }
    }
    
    return @{Success=$false; Error="Unknown domain role name"}
}

# Set permissions on base folder: Deaktiviere Vererbung
$acl = Get-Acl $basePath
$acl.SetAccessRuleProtection($true, $false) # Deaktiviert die Vererbung
Set-Acl -Path $basePath -AclObject $acl

# Restrict domain users from creating directories in Firmendaten
# Try different approaches to get Domain Users
#$domainUsers = "$domainPrefix\Domain Users"
$domainUsersSID = Get-DomainRoleSID -RoleName "DomainUsers"

if ($domainUsersSID.Success) {
    Write-Host "Using Domain Users SID: $($domainUsersSID.SID.Value)"
    $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $domainUsersSID.SID,
        "CreateDirectories",
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Deny
    )
    try {
        $acl = Get-Acl $basePath
        $acl.AddAccessRule($denyRule)
        Set-Acl -Path $basePath -AclObject $acl
        Write-Host "Added deny rule for Domain Users SID successfully."
    } catch {
        Write-Host "Fehler beim Hinzufuegen der Deny-Regel fuer Domain Users SID: $($_.Exception.Message)"
    }
} else {
    # Try with localized names as fallbacks
    $localizedNames = @("$domainPrefix\Domain Users", "$domainPrefix\Domaenenbenutzer", "$domainPrefix\Domainbenutzer")
    $success = $false
    
    foreach ($name in $localizedNames) {
        $checkedUser = Test-SecurityPrincipal -Name $name
        if ($checkedUser.Success) {
            $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $checkedUser.Account,
                "CreateDirectories",
                [System.Security.AccessControl.InheritanceFlags]::None,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Deny
            )
            try {
                $acl = Get-Acl $basePath
                $acl.AddAccessRule($denyRule)
                Set-Acl -Path $basePath -AclObject $acl
                Write-Host "Added deny rule for $name successfully."
                $success = $true
                break
            } catch {
                Write-Host "Fehler beim Hinzufuegen der Deny-Regel fuer $($name): $($_.Exception.Message)"
            }
        }
    }
    
    if (-not $success) {
        Write-Warning "Could not restrict Domain Users from creating directories. Tried SID and localized names."
    }
}

# Get well-known SIDs
$adminsSID = Get-WellKnownSID -WellKnownName "Administrators"
$systemSID = Get-WellKnownSID -WellKnownName "System"
$domainAdminsSID = Get-DomainRoleSID -RoleName "DomainAdmins"

Write-Host "Using well-known SIDs:"
Write-Host "Administrators SID success: $($adminsSID.Success)"
Write-Host "System SID success: $($systemSID.Success)"
Write-Host "Domain Admins SID success: $($domainAdminsSID.Success)"

# Assign permissions to DL-Gruppen
$permissions = @(
    # Gefue-Daten
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-L"; Access="ReadAndExecute"}
)

# Add system permissions using SIDs if available
if ($systemSID.Success) {
    $permissions += @{Path="$basePath\Gefue-Daten"; UserSID=$systemSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Vertrieb-Daten"; UserSID=$systemSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Versand-Daten"; UserSID=$systemSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Shared-Daten"; UserSID=$systemSID.SID; Access="FullControl"}
} else {
    # Fallback to string name
    $permissions += @{Path="$basePath\Gefue-Daten"; User="NT AUTHORITY\SYSTEM"; Access="FullControl"}
    $permissions += @{Path="$basePath\Vertrieb-Daten"; User="NT AUTHORITY\SYSTEM"; Access="FullControl"}
    $permissions += @{Path="$basePath\Versand-Daten"; User="NT AUTHORITY\SYSTEM"; Access="FullControl"}
    $permissions += @{Path="$basePath\Shared-Daten"; User="NT AUTHORITY\SYSTEM"; Access="FullControl"}
}


# Add administrators permissions using SIDs if available
if ($adminsSID.Success) {
    $permissions += @{Path="$basePath\Gefue-Daten"; UserSID=$adminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Vertrieb-Daten"; UserSID=$adminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Versand-Daten"; UserSID=$adminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Shared-Daten"; UserSID=$adminsSID.SID; Access="FullControl"}
}

# Add domain admins permissions using SIDs if available
<#if ($domainAdminsSID.Success) {
    $permissions += @{Path="$basePath\Gefue-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Vertrieb-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Versand-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Shared-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
}
#>
# Add remaining department permissions
$permissions += @(
    # Vertrieb-Daten
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-L"; Access="ReadAndExecute"},
    
    # Versand-Daten
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-L"; Access="ReadAndExecute"},
    
    # Shared-Daten
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Shared-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Shared-Daten-L"; Access="ReadAndExecute"}
)

foreach ($perm in $permissions) {
    $acl = Get-Acl $perm.Path
    $inheritFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
                     [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    
    # Check if we're using a SID or a name
    if ($perm.ContainsKey("UserSID")) {
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $perm.UserSID,
            $perm.Access,
            $inheritFlags,
            $propagationFlags,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        try {
            $acl.AddAccessRule($accessRule)
            Set-Acl -Path $perm.Path -AclObject $acl
            Write-Host "Set $($perm.Access) permission for SID $($perm.UserSID.Value) on $($perm.Path)"
        } catch {
            Write-Warning "Failed to set permission for SID $($perm.UserSID.Value) on $($perm.Path): $($_.Exception.Message)"
        }
    } else {
        # Check if the user can be resolved
        $checkedUser = Test-SecurityPrincipal -Name $perm.User
        if ($checkedUser.Success) {
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $checkedUser.Account,
                $perm.Access,
                $inheritFlags,
                $propagationFlags,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            try {
                $acl.AddAccessRule($accessRule)
                Set-Acl -Path $perm.Path -AclObject $acl
                Write-Host "Set $($perm.Access) permission for $($perm.User) on $($perm.Path)"
            } catch {
                Write-Warning "Failed to set permission for $($perm.User) on $($perm.Path): $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Security principal '$($perm.User)' could not be resolved: $($checkedUser.Error)"
        }
    }
}

# Erstelle SMB-Freigaben für alle Ordner
foreach ($folder in $folders) {
    # Bestimme den Freigabenamen basierend auf dem Ordnernamen
    $folderName = Split-Path $folder -Leaf
    
    # Spezialfall für den Home-Ordner
    if ($folder -eq $homePath) {
        $shareName = "Home$"
    } else {
        $shareName = $folderName
    }
    
    # Prüfe, ob die Freigabe bereits existiert
    if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        try {
            # Erstelle die Freigabe ohne explizite Berechtigungen zuerst
            if ($folder -eq $basePath) {
                # Spezialfall für den Firmendaten-Ordner
                New-SmbShare -Name $shareName -Path $folder -FolderEnumerationMode AccessBased
            } else {
                # Für alle anderen Ordner
                New-SmbShare -Name $shareName -Path $folder
            }
            
            # Füge die Berechtigungen separat hinzu
            Grant-SmbShareAccess -Name $shareName -AccountName "Jeder" -AccessRight Full -Force
            Write-Host "Erstellt: SMB-Freigabe '$shareName' für Ordner: $folder"
        }
        catch {
            Write-Warning "Fehler beim Erstellen der Freigabe für $folder : $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "SMB-Freigabe '$shareName' existiert bereits."
    }
}

#==========================================================================================================================================================================
# Stelle sicher, dass das AD-Modul geladen ist
#Import-Module ActiveDirectory -ErrorAction Stop

# Konfiguration: Fileserver, Homefolder Share, lokale Basis
$fileserver     = $env:COMPUTERNAME            # Hier den tatsaechlichen Fileservernamen eintragen
$homeShareName  = "Home$"                   # Freigabenamen; mit $ als versteckt
$homeRootLocal  = "E:\Home"                 # Lokaler Pfad, in dem die Homefolder erstellt werden
$homeDriveLetter = "H:"                    # Laufwerksbuchstabe fuer den Homefolder

# Nur diese spezifischen Benutzer sollen Homefolders bekommen
#$allowedUsers = @("max.mitte", "ute.unten", "olaf.oben")

# Hole nur die explizit erlaubten Benutzer mit einem präziseren Filter
$users = Get-ADUser -Filter "SamAccountName -eq 'max.mitte' -or SamAccountName -eq 'ute.unten' -or SamAccountName -eq 'olaf.oben'"

foreach ($user in $users) {
    $username = $user.SamAccountName
    
    # Lokalen Pfad fuer den Homefolder des Benutzers erstellen
    $userHomeFolderLocal = Join-Path $homeRootLocal $username
    
    # UNC-Pfad fuer den Homefolder, der in AD gesetzt wird
    $userHomeFolderUNC = "\\$fileserver\$homeShareName\$username"
    
    # Homefolder anlegen, falls er noch nicht existiert
    if (-not (Test-Path -Path $userHomeFolderLocal)) {
        try {
            New-Item -Path $userHomeFolderLocal -ItemType Directory | Out-Null
            Write-Host "Erstellt: Homefolder fuer Benutzer $username unter $userHomeFolderLocal"
        } catch {
            Write-Warning "Fehler beim Erstellen des Homefolders fuer $username $($_.Exception.Message)"
            continue
        }
    } else {
        Write-Host "Homefolder fuer $username existiert bereits."
    }
    
    # ------------------------------- 
    # Optional: NTFS-Berechtigungen setzen
    # -------------------------------
    try {
        # Lade die aktuelle ACL des Benutzerordners
        $acl = Get-Acl $userHomeFolderLocal

        # Deaktiviere die Vererbung und entferne alle geerbten Berechtigungen
        $acl.SetAccessRuleProtection($true, $false)
        
        # Entferne alle bestehenden Berechtigungen
        foreach ($accessRule in $acl.Access) {
            $acl.RemoveAccessRule($accessRule) | Out-Null
        }

        # Berechne die Vererbungsflags im Voraus
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None

        # Erstelle die Zugriffsregel für den Benutzer als NT-Account (nicht als SID)
        $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$env:USERDOMAIN\$username",  # Domain\Username Format verwenden
            "FullControl",
            $inheritanceFlags,
            $propagationFlags,
            [System.Security.AccessControl.AccessControlType]::Allow
        )

        # Zugriffsregel für SYSTEM
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM",
            "FullControl",
            $inheritanceFlags,
            $propagationFlags,
            [System.Security.AccessControl.AccessControlType]::Allow
        )

        # Zugriffsregel für lokale Administratoren
        $adminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "BUILTIN\Administrators",
            "FullControl",
            $inheritanceFlags,
            $propagationFlags,
            [System.Security.AccessControl.AccessControlType]::Allow
        )

        # Füge nur die gewünschten Regeln hinzu (Domain Users nicht einschließen)
        $acl.AddAccessRule($userRule)
        $acl.AddAccessRule($systemRule)
        $acl.AddAccessRule($adminsRule)

        # Versuche Domain Admins hinzuzufügen, falls verfügbar
        try {
            $domainAdminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "$env:USERDOMAIN\Domain Admins",
                "FullControl",
                $inheritanceFlags,
                $propagationFlags,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl.AddAccessRule($domainAdminsRule)
        } catch {
            Write-Warning "Domain Admins-Gruppe konnte nicht hinzugefügt werden: $($_.Exception.Message)"
        }

        # Die aktualisierte ACL zurück auf den Ordner setzen
        Set-Acl -Path $userHomeFolderLocal -AclObject $acl
        Write-Host "NTFS-Berechtigungen für $userHomeFolderLocal gesetzt."
    }
    catch {
        Write-Warning "Fehler beim Setzen der NTFS-Berechtigungen für $($userHomeFolderLocal): $($_.Exception.Message)"
    }

    # ------------------------------- 
    # AD-Attribute des Benutzers aktualisieren
    # ------------------------------- 
    try {
        Set-ADUser $user -HomeDirectory $userHomeFolderUNC -HomeDrive $homeDriveLetter
        Write-Host "AD-Eintrag fuer $username aktualisiert: HomeDirectory = $userHomeFolderUNC, HomeDrive = $homeDriveLetter"
    }
    catch {
        Write-Warning "Fehler beim Setzen der AD-Attribute fuer $username $($_.Exception.Message)"
    }
}
