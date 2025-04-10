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

# Set permissions on base folder: Deaktiviere Vererbung
$acl = Get-Acl $basePath
$acl.SetAccessRuleProtection($true, $false) # Deaktiviert die Vererbung
Set-Acl -Path $basePath -AclObject $acl

# Restrict domain users from creating directories in Firmendaten
$domainUsers = "$domainPrefix\Domain Users"
$checkedUser = Test-SecurityPrincipal -Name $domainUsers
if ($checkedUser.Success) {
    $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $checkedUser.Account,
        "CreateDirectories",
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Deny
    )
    try {
        $acl.AddAccessRule($denyRule)
        Set-Acl -Path $basePath -AclObject $acl
        Write-Host "Added deny rule for $domainUsers successfully."
    } catch {
        Write-Host "Fehler beim Hinzufuegen der Deny-Regel fuer $($domainUsers): $($_.Exception.Message)"
    }
} else {
    Write-Host "Security principal '$domainUsers' could not be resolved: $($checkedUser.Error)"
}

# Define accounts that need special handling
$builtInAdmins = "BUILTIN\Administrators"
$domainAdmins = "$domainPrefix\Domain Admins" 
$systemAccount = "NT AUTHORITY\SYSTEM"

# Verify these accounts can be resolved
$checkedAdmins = Test-SecurityPrincipal -Name $builtInAdmins
$checkedDomAdmins = Test-SecurityPrincipal -Name $domainAdmins
$checkedSystem = Test-SecurityPrincipal -Name $systemAccount

Write-Host "Account verification results:"
Write-Host "BUILTIN\Administrators: $($checkedAdmins.Success)"
Write-Host "Domain Admins: $($checkedDomAdmins.Success)"
Write-Host "SYSTEM: $($checkedSystem.Success)"

# Assign permissions to DL-Gruppen
$permissions = @(
    # Gefue-Daten
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Gefue-Daten"; User="$domainPrefix\DL-Gefue-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Gefue-Daten"; User=$systemAccount; Access="FullControl"},
    @{Path="$basePath\Gefue-Daten"; User=$builtInAdmins; Access="FullControl"},
    @{Path="$basePath\Gefue-Daten"; User=$domainAdmins; Access="FullControl"},

    # Vertrieb-Daten
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Vertrieb-Daten"; User="$domainPrefix\DL-Vertrieb-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Vertrieb-Daten"; User=$systemAccount; Access="FullControl"},
    @{Path="$basePath\Vertrieb-Daten"; User=$builtInAdmins; Access="FullControl"},
    @{Path="$basePath\Vertrieb-Daten"; User=$domainAdmins; Access="FullControl"},
    
    # Versand-Daten
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Versand-Daten"; User="$domainPrefix\DL-Versand-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Versand-Daten"; User=$systemAccount; Access="FullControl"},
    @{Path="$basePath\Versand-Daten"; User=$builtInAdmins; Access="FullControl"},
    @{Path="$basePath\Versand-Daten"; User=$domainAdmins; Access="FullControl"},
    
    # Shared-Daten
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Shared-Daten-AE"; Access="Modify"},
    @{Path="$basePath\Shared-Daten"; User="$domainPrefix\DL-Shared-Daten-L"; Access="ReadAndExecute"},
    @{Path="$basePath\Shared-Daten"; User=$systemAccount; Access="FullControl"},
    @{Path="$basePath\Shared-Daten"; User=$builtInAdmins; Access="FullControl"},
    @{Path="$basePath\Shared-Daten"; User=$domainAdmins; Access="FullControl"}
)

foreach ($perm in $permissions) {
    $acl = Get-Acl $perm.Path
    $inheritFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
                     [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    
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

# Erstelle SMB-Freigaben fuer die Unterordner in Firmendaten (ohne $basePath und $homePath)
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



