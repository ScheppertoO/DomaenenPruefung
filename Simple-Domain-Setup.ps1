# ========================================================================
# EINFACHES DOMAIN-SETUP SKRIPT
# ========================================================================
# Einfach zu verwendendes Skript für Domain-Konfiguration
# Nur die Konfiguration oben ändern, der Rest läuft automatisch

# ========================================================================
# *** HIER IHRE KONFIGURATION EINTRAGEN ***
# ========================================================================

# 1. FIRMA UND DOMAIN
$CompanyName = "Technotrans"           # Name Ihrer Firma
$DomainName = "DC=Demo,DC=dom"         # Ihre Domain
$DomainSuffix = "@Demo.dom"            # Domain-Suffix für E-Mail
$DefaultPassword = "Password1"         # Standard-Passwort für alle Benutzer

# 2. BENUTZER HINZUFÜGEN/ÄNDERN
# Format: "Vollname|Vorname|Nachname|Abteilung|Benutzername|Ordnerberechtigung"
# Ordnerberechtigung: "Read" oder "Modify"
$UserList = @(
    "Ute Uber|Ute|Uber|Versand|ute.uber|Read",
    "Max Mitte|Max|Mitte|Vertrieb|max.mitte|Modify", 
    "Olaf Oben|Olaf|Oben|Geschaeftsfuehrung|olaf.oben|Modify"
)

# 3. OPTIONALE EINSTELLUNGEN
$CreateFolders = $true                 # Ordner erstellen? ($true/$false)
$CreateShares = $true                  # Netzwerkfreigaben erstellen? ($true/$false)
$FolderBasePath = "E:\Firmendaten"     # Wo sollen Ordner erstellt werden?
$CreateVPN = $false                    # VPN-Verbindungen erstellen? ($true/$false)
$VPNServer = "vpn.technotrans.com"     # VPN-Server Adresse

# ========================================================================
# *** AB HIER NICHTS MEHR ÄNDERN (außer Sie wissen was Sie tun) ***
# ========================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DOMAIN-SETUP FÜR: $CompanyName" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan

# Benutzer-Array erstellen
$Users = @()
foreach ($userString in $UserList) {
    $parts = $userString -split '\|'
    if ($parts.Count -eq 6) {
        $Users += @{
            Name = $parts[0].Trim()
            FirstName = $parts[1].Trim()
            LastName = $parts[2].Trim()
            Department = $parts[3].Trim()
            Username = $parts[4].Trim()
            FolderPermission = $parts[5].Trim()
            OUName = "$($parts[3].Trim())-Abt"
            FolderName = "$($parts[3].Trim())-Daten"
        }
    }
}

Write-Host "Gefundene Benutzer: $($Users.Count)" -ForegroundColor Yellow
foreach ($user in $Users) {
    Write-Host "  - $($user.Name) ($($user.Department))" -ForegroundColor Gray
}

# Active Directory Modul laden
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "✓ Active Directory Modul geladen" -ForegroundColor Green
} catch {
    Write-Error "Fehler: Active Directory Modul nicht verfügbar!"
    exit 1
}

# 1. BASIS-OU ERSTELLEN
Write-Host "`nErstelle Basis-OU..." -ForegroundColor Yellow
try {
    New-ADOrganizationalUnit -Name $CompanyName -Path $DomainName -ErrorAction SilentlyContinue
    Write-Host "✓ Basis-OU: $CompanyName" -ForegroundColor Green
} catch {
    Write-Host "! Basis-OU existiert bereits" -ForegroundColor Orange
}

# 2. ABTEILUNGS-OUs ERSTELLEN
Write-Host "`nErstelle Abteilungs-OUs..." -ForegroundColor Yellow
$uniqueDepartments = $Users | Select-Object -ExpandProperty Department -Unique
foreach ($dept in $uniqueDepartments) {
    $ouName = "$dept-Abt"
    try {
        New-ADOrganizationalUnit -Name $ouName -Path "OU=$CompanyName,$DomainName" -ErrorAction SilentlyContinue
        Write-Host "✓ Abteilungs-OU: $ouName" -ForegroundColor Green
    } catch {
        Write-Host "! OU existiert bereits: $ouName" -ForegroundColor Orange
    }
}

# 3. BENUTZER ERSTELLEN  
Write-Host "`nErstelle Benutzer..." -ForegroundColor Yellow
foreach ($user in $Users) {
    $userPath = "OU=$($user.OUName),OU=$CompanyName,$DomainName"
    $userPrincipalName = "$($user.Username)$DomainSuffix"
    
    try {
        $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($user.Username)'" -ErrorAction SilentlyContinue
        if (-not $existingUser) {
            New-ADUser -Name $user.Name `
                      -GivenName $user.FirstName `
                      -Surname $user.LastName `
                      -SamAccountName $user.Username `
                      -UserPrincipalName $userPrincipalName `
                      -Path $userPath `
                      -AccountPassword (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force) `
                      -Enabled $true `
                      -PasswordNeverExpires $true `
                      -ErrorAction Stop
            Write-Host "✓ Benutzer erstellt: $($user.Name)" -ForegroundColor Green
        } else {
            Write-Host "! Benutzer existiert bereits: $($user.Username)" -ForegroundColor Orange
        }
    } catch {
        Write-Host "✗ Fehler bei Benutzer $($user.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 4. ORDNER ERSTELLEN (wenn aktiviert)
if ($CreateFolders) {
    Write-Host "`nErstelle Ordnerstruktur..." -ForegroundColor Yellow
    
    # Basis-Ordner
    if (-not (Test-Path $FolderBasePath)) {
        New-Item -Path $FolderBasePath -ItemType Directory -Force | Out-Null
        Write-Host "✓ Basis-Ordner: $FolderBasePath" -ForegroundColor Green
    }
    
    # Benutzer-Ordner
    foreach ($user in $Users) {
        $folderPath = Join-Path $FolderBasePath $user.FolderName
        
        try {
            # Ordner erstellen
            New-Item -Path $folderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            
            # Berechtigungen setzen
            $acl = Get-Acl $folderPath
            $permission = if ($user.FolderPermission -eq "Read") { "Read" } else { "Modify" }
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $user.Name, $permission, "ContainerInherit, ObjectInherit", "None", "Allow"
            )
            $acl.AddAccessRule($rule)
            Set-Acl $folderPath $acl
            
            Write-Host "✓ Ordner: $($user.FolderName) ($permission für $($user.Name))" -ForegroundColor Green
        } catch {
            Write-Host "✗ Fehler bei Ordner $($user.FolderName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 5. NETZWERKFREIGABEN (wenn aktiviert)
if ($CreateShares) {
    Write-Host "`nErstelle Netzwerkfreigaben..." -ForegroundColor Yellow
    
    foreach ($user in $Users) {
        $folderPath = Join-Path $FolderBasePath $user.FolderName
        $shareName = $user.FolderName
        
        if (Test-Path $folderPath) {
            try {
                $shareAccess = if ($user.FolderPermission -eq "Read") { "ReadAccess" } else { "FullAccess" }
                $shareParams = @{
                    Name = $shareName
                    Path = $folderPath
                    $shareAccess = $user.Name
                    ErrorAction = "Stop"
                }
                
                # Prüfen ob Freigabe bereits existiert
                $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
                if (-not $existingShare) {
                    New-SmbShare @shareParams | Out-Null
                    Write-Host "✓ Freigabe: $shareName ($shareAccess für $($user.Name))" -ForegroundColor Green
                } else {
                    Write-Host "! Freigabe existiert bereits: $shareName" -ForegroundColor Orange
                }
            } catch {
                Write-Host "✗ Fehler bei Freigabe $shareName`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# 6. VPN-VERBINDUNGEN (wenn aktiviert)
if ($CreateVPN) {
    Write-Host "`nErstelle VPN-Verbindungen..." -ForegroundColor Yellow
    
    $vpnTypes = @(
        @{ Name = "VPN PPTP"; Type = "Pptp" },
        @{ Name = "VPN L2TP"; Type = "L2tp" },
        @{ Name = "VPN SSTP"; Type = "Sstp" }
    )
    
    foreach ($vpn in $vpnTypes) {
        try {
            $vpnParams = @{
                Name = $vpn.Name
                ServerAddress = $VPNServer
                TunnelType = $vpn.Type
                AuthenticationMethod = "EAP"
                SplitTunneling = $true
                ErrorAction = "Stop"
            }
            
            if ($vpn.Type -eq "L2tp") {
                $vpnParams.L2tpPsk = "PreSharedKey"
            }
            
            Add-VpnConnection @vpnParams
            Write-Host "✓ VPN erstellt: $($vpn.Name)" -ForegroundColor Green
        } catch {
            Write-Host "✗ Fehler bei VPN $($vpn.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ZUSAMMENFASSUNG
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SETUP ABGESCHLOSSEN!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firma: $CompanyName" -ForegroundColor White
Write-Host "Domain: $DomainName" -ForegroundColor White  
Write-Host "Benutzer erstellt: $($Users.Count)" -ForegroundColor White
Write-Host "Standard-Passwort: $DefaultPassword" -ForegroundColor Yellow
if ($CreateFolders) { Write-Host "Ordner erstellt: $FolderBasePath" -ForegroundColor White }
if ($CreateShares) { Write-Host "Freigaben erstellt: Ja" -ForegroundColor White }
if ($CreateVPN) { Write-Host "VPN-Verbindungen: Ja" -ForegroundColor White }
Write-Host "========================================" -ForegroundColor Cyan
