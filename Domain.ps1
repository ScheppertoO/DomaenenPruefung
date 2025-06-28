# ========================================================================
# KONFIGURATION - Hier alle wichtigen Parameter anpassen
# ========================================================================

# Domain-Konfiguration
$DomainConfig = @{
    CompanyName = "Technotrans"
    DomainDN = "DC=demo,DC=dom"
    DomainSuffix = "@demo.dom"
    DefaultPassword = "Password1"
}

# Benutzer und Abteilungen definieren
$UsersConfig = @(
    @{
        Name = "Olaf Oben"
        SamAccountName = "Olaf.Oben"
        Department = "Geschaeftsfuehrung"
        OUName = "Gefue-Abt"
        FolderName = "Gefue-Daten"
        FolderPermission = "Modify"
    },
    @{
        Name = "Max Mitte"
        SamAccountName = "Max.Mitte"
        Department = "Vertrieb"
        OUName = "Vertrieb-Abt"
        FolderName = "Vertrieb-Daten"
        FolderPermission = "Modify"
    },
    @{
        Name = "Ute Unten"
        SamAccountName = "Ute.Unten"
        Department = "Versand"
        OUName = "Versand-Abt"
        FolderName = "Versand-Daten"
        FolderPermission = "Read"
    }
)

# Fileserver-Konfiguration
$FileServerConfig = @{
    BasePath = "E:\Firmendaten"
    CreateFolders = $true
    CreateShares = $true
}

# VPN-Konfiguration
$VPNConfig = @{
    ServerAddress = "vpn.technotrans.com"
    PreSharedKey = "PreSharedKey"
    CreateVPN = $false  # Auf $true setzen, wenn VPN-Verbindungen erstellt werden sollen
}

# ========================================================================
# SKRIPT-AUSFÜHRUNG - Nicht ändern, außer Sie wissen was Sie tun
# ========================================================================

Write-Host "Beginne Domain-Setup für $($DomainConfig.CompanyName)..." -ForegroundColor Green

# Basis-OU erstellen
Write-Host "Erstelle Basis-OU: $($DomainConfig.CompanyName)" -ForegroundColor Yellow
try {
    New-ADOrganizationalUnit -Name $DomainConfig.CompanyName -Path $DomainConfig.DomainDN -ErrorAction SilentlyContinue
    Write-Host "✓ Basis-OU erstellt" -ForegroundColor Green
} catch {
    Write-Host "! Basis-OU existiert bereits oder Fehler: $($_.Exception.Message)" -ForegroundColor Orange
}

# Abteilungs-OUs erstellen
Write-Host "Erstelle Abteilungs-OUs..." -ForegroundColor Yellow
$basePath = "OU=$($DomainConfig.CompanyName),$($DomainConfig.DomainDN)"
foreach ($user in $UsersConfig) {
    try {
        New-ADOrganizationalUnit -Name $user.OUName -Path $basePath -ErrorAction SilentlyContinue
        Write-Host "✓ OU erstellt: $($user.OUName)" -ForegroundColor Green
    } catch {
        Write-Host "! OU existiert bereits oder Fehler: $($user.OUName)" -ForegroundColor Orange
    }
}

# Benutzer erstellen
Write-Host "Erstelle Benutzer..." -ForegroundColor Yellow
foreach ($user in $UsersConfig) {
    $userPath = "OU=$($user.OUName),OU=$($DomainConfig.CompanyName),$($DomainConfig.DomainDN)"
    $userPrincipalName = "$($user.SamAccountName)$($DomainConfig.DomainSuffix)"
    
    try {
        New-ADUser -Name $user.Name `
                   -SamAccountName $user.SamAccountName `
                   -UserPrincipalName $userPrincipalName `
                   -Path $userPath `
                   -AccountPassword (ConvertTo-SecureString $DomainConfig.DefaultPassword -AsPlainText -Force) `
                   -PasswordNeverExpires $true `
                   -Enabled $true `
                   -ErrorAction Stop
        Write-Host "✓ Benutzer erstellt: $($user.Name)" -ForegroundColor Green
    } catch {
        Write-Host "! Benutzer existiert bereits oder Fehler: $($user.Name) - $($_.Exception.Message)" -ForegroundColor Orange
    }
}


# Dateisystem-Setup (nur wenn aktiviert)
if ($FileServerConfig.CreateFolders) {
    Write-Host "Erstelle Ordnerstruktur..." -ForegroundColor Yellow
    
    # Basis-Ordner erstellen
    if (-not (Test-Path $FileServerConfig.BasePath)) {
        New-Item -Path $FileServerConfig.BasePath -ItemType Directory -Force
        Write-Host "✓ Basis-Ordner erstellt: $($FileServerConfig.BasePath)" -ForegroundColor Green
    }
    
    # Benutzer-spezifische Ordner und Berechtigungen
    foreach ($user in $UsersConfig) {
        $folderPath = Join-Path $FileServerConfig.BasePath $user.FolderName
        
        # Ordner erstellen
        try {
            New-Item -Path $folderPath -ItemType Directory -Force -ErrorAction Stop
            Write-Host "✓ Ordner erstellt: $folderPath" -ForegroundColor Green
        } catch {
            Write-Host "! Fehler beim Erstellen des Ordners: $folderPath - $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
        
        # NTFS-Berechtigungen setzen
        try {
            $acl = Get-Acl $folderPath
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $user.Name, 
                $user.FolderPermission, 
                "ContainerInherit, ObjectInherit", 
                "None", 
                "Allow"
            )
            $acl.AddAccessRule($rule)
            Set-Acl $folderPath $acl
            Write-Host "✓ Berechtigungen gesetzt: $($user.Name) -> $($user.FolderPermission) auf $folderPath" -ForegroundColor Green
        } catch {
            Write-Host "! Fehler beim Setzen der Berechtigungen: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Netzwerkfreigaben erstellen (nur wenn aktiviert)
if ($FileServerConfig.CreateShares) {
    Write-Host "Erstelle Netzwerkfreigaben..." -ForegroundColor Yellow
    
    foreach ($user in $UsersConfig) {
        $folderPath = Join-Path $FileServerConfig.BasePath $user.FolderName
        $shareName = $user.FolderName
        
        try {
            # Bestimme Freigabe-Berechtigung basierend auf Ordner-Berechtigung
            $shareAccess = if ($user.FolderPermission -eq "Read") { "ReadAccess" } else { "FullAccess" }
            
            $shareParams = @{
                Name = $shareName
                Path = $folderPath
                $shareAccess = $user.Name
                ErrorAction = "Stop"
            }
            
            New-SmbShare @shareParams
            Write-Host "✓ Freigabe erstellt: $shareName -> $($user.Name) ($shareAccess)" -ForegroundColor Green
        } catch {
            Write-Host "! Fehler beim Erstellen der Freigabe: $shareName - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# VPN-Verbindungen erstellen (nur wenn aktiviert)
if ($VPNConfig.CreateVPN) {
    Write-Host "Erstelle VPN-Verbindungen..." -ForegroundColor Yellow
    
    $vpnConnections = @(
        @{ Name = "VPN PPTP"; TunnelType = "Pptp"; AuthMethod = "EAP" },
        @{ Name = "VPN L2TP"; TunnelType = "L2tp"; AuthMethod = "EAP"; UsePSK = $true },
        @{ Name = "VPN SSTP"; TunnelType = "Sstp"; AuthMethod = "EAP" }
    )
    
    foreach ($vpn in $vpnConnections) {
        try {
            $vpnParams = @{
                Name = $vpn.Name
                ServerAddress = $VPNConfig.ServerAddress
                TunnelType = $vpn.TunnelType
                AuthenticationMethod = $vpn.AuthMethod
                SplitTunneling = $true
                ErrorAction = "Stop"
            }
            
            if ($vpn.UsePSK) {
                $vpnParams.L2tpPsk = $VPNConfig.PreSharedKey
            }
            
            Add-VpnConnection @vpnParams
            Write-Host "✓ VPN-Verbindung erstellt: $($vpn.Name)" -ForegroundColor Green
        } catch {
            Write-Host "! Fehler beim Erstellen der VPN-Verbindung: $($vpn.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`nDomain-Setup abgeschlossen!" -ForegroundColor Green
Write-Host "Zusammenfassung:" -ForegroundColor Cyan
Write-Host "- Firma: $($DomainConfig.CompanyName)" -ForegroundColor White
Write-Host "- Domain: $($DomainConfig.DomainDN)" -ForegroundColor White
Write-Host "- Benutzer erstellt: $($UsersConfig.Count)" -ForegroundColor White
Write-Host "- Standard-Passwort: $($DomainConfig.DefaultPassword)" -ForegroundColor White
if ($FileServerConfig.CreateFolders) {
    Write-Host "- Ordner erstellt: $($FileServerConfig.BasePath)" -ForegroundColor White
}
if ($FileServerConfig.CreateShares) {
    Write-Host "- Freigaben erstellt: Ja" -ForegroundColor White
}
if ($VPNConfig.CreateVPN) {
    Write-Host "- VPN-Verbindungen: Ja" -ForegroundColor White
}