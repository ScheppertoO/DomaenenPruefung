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
    "$basePath\Shared-Daten",
    $homePath,
    "$homepath\Olaf.Oben",
    "$homepath\Ute.Unten",
    "$homepath\Max.Mitte"
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
$domainUsers = "$domainPrefix\Domain Users"
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
    $localizedNames = @("$domainPrefix\Domain Users", "$domainPrefix\Domänenbenutzer", "$domainPrefix\Domainbenutzer")
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
if ($domainAdminsSID.Success) {
    $permissions += @{Path="$basePath\Gefue-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Vertrieb-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Versand-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
    $permissions += @{Path="$basePath\Shared-Daten"; UserSID=$domainAdminsSID.SID; Access="FullControl"}
}

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



# Erstelle SMB-Freigaben fuer die Unterordner in Firmendaten (ohne $basePath und $homePath)
<# $baseSubFolders = @(
    "$basePath\Gefue-Daten",
    "$basePath\Vertrieb-Daten",
    "$basePath\Versand-Daten",
    "$basePath\Shared-Daten",
    $homePath,
    "$homePath\Ute.Unten",
    "$homePath\Olaf.Oben",
    "$homePath\Max.Mitte"

)

foreach ($folder in $baseSubFolders) {
    # Nutzt den Ordnernamen als Share-Namen
    $shareName = Split-Path $folder -Leaf
    # Anstatt den Servernamen zu verwenden, wird hier die Domaingruppe verwendet
    $fullAccessAccount = "$domainPrefix\DL-$shareName-AE"
    # Verify the account can be resolved
    $checkedAccount = Test-SecurityPrincipal -Name $fullAccessAccount
    
    if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        try {
            if ($checkedAccount.Success) {
                New-SmbShare -Name $shareName -Path $folder -FullAccess $fullAccessAccount
                Write-Host "Netzwerkfreigabe erstellt: $shareName"
            } else {
                # Fallback to creating the share without specific permissions
                New-SmbShare -Name $shareName -Path $folder
                Write-Host "Netzwerkfreigabe erstellt: $shareName (ohne spezifische Berechtigungen)"
                Write-Warning "Security principal '$fullAccessAccount' could not be resolved: $($checkedAccount.Error)"
            }
        } catch {
            Write-Host "Fehler beim Erstellen der Freigabe fuer $($folder): $($_.Exception.Message)"
        }
    } else {
        Write-Host "Share $shareName existiert bereits, keine Aktion erforderlich."
    }
}
#>

#==========================================================================================================================================================================
#                                                                                            ChatGPTs Lösung für die SMB-Share funktionen 
#==========================================================================================================================================================================
$fullAccessArray = @(
    "Everyone", 
    "$domainPrefix\Domain Admins", 
    "NT AUTHORITY\SYSTEM", 
    "BUILTIN\Administrators"
)

foreach ($folder in $folders) {
    # Falls der Ordner nicht existiert, überspringe ihn
    if (-not (Test-Path -Path $folder)) {
        Write-Host "Ordner $folder existiert nicht, überspringe..."
        continue
    }
    
    # Setze den Freigabenamen:
    # - Homeordner bekommt explizit den Namen "Home$"
    # - Alle anderen erhalten ihren Ordnernamen als Freigabe
    if ($folder -eq $homePath) {
        $shareName = "Home$"
    }
    else {
        $shareName = Split-Path $folder -Leaf
    }

    # Wenn es sich um den Firmendatenordner ($basePath) handelt, aktiviere die zugriffsbasierte Aufzählung.
    $extraParams = @{}
    if ($folder -eq $basePath) {
        $extraParams["FolderEnumerationMode"] = "AccessBased"
    }

    # Prüfen, ob das SMB-Share bereits existiert.
    if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        try {
            if ($extraParams.Count -gt 0) {
                New-SmbShare -Name $shareName -Path $folder -FullAccess $fullAccessArray -FolderEnumerationMode $extraParams["FolderEnumerationMode"]
            }
            else {
                New-SmbShare -Name $shareName -Path $folder -FullAccess $fullAccessArray
            }
            Write-Host "Freigabe erstellt: $shareName für $folder"
        }
        catch {
            Write-Host "Fehler beim Erstellen der Freigabe $shareName für $($folder): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Freigabe $shareName existiert bereits, keine Aktion erforderlich."
    }
}