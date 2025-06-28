# ========================================================================
# ERWEITERTE BENUTZER- UND OU-VERWALTUNG MIT ADGLP-PRINZIP
# ========================================================================

# ========================================================================
# KONFIGURATION - Hier alle wichtigen Parameter anpassen
# ========================================================================

# Domain-Grundkonfiguration
$DomainConfig = @{
    CompanyName = "Technotrans"
    DomainDN = "DC=Demo,DC=dom"
    DomainSuffix = "@Demo.dom"
    DefaultPassword = "Password1"
}

# Benutzer-Konfiguration mit Abteilungen und Berechtigungen
$UsersConfig = @(
    @{
        Name = "Ute Uber"
        FirstName = "Ute"
        LastName = "Uber"
        Department = "Versand"
        OUName = "Versand-Abt"
        Username = "ute.uber"  # Optional: Wird automatisch generiert wenn leer
        Permissions = @("DL-Versand-Daten-R")  # Spezifische Berechtigungen
    },
    @{
        Name = "Max Mitte"
        FirstName = "Max"
        LastName = "Mitte"
        Department = "Vertrieb"
        OUName = "Vertrieb-Abt"
        Username = "max.mitte"
        Permissions = @("DL-Vertrieb-Daten-AE")
    },
    @{
        Name = "Olaf Oben"
        FirstName = "Olaf"
        LastName = "Oben"
        Department = "Geschaeftsfuehrung"
        OUName = "Gefue-Abt"
        Username = "olaf.oben"
        Permissions = @("DL-Gefue-Daten-AE", "DL-Versand-Daten-R")
    },
    @{
        Name = "Maria Koenig"
        FirstName = "Maria"
        LastName = "Koenig"
        Department = "DomainAdmins"
        OUName = "DomainAdmins"
        Username = "maria.koenig"
        Permissions = @()  # Keine spezifischen Berechtigungen
    }
)

# Abteilungs-Mapping (für interne Verarbeitung)
$DepartmentMapping = @{
    "Geschaeftsfuehrung" = "Gefue"
    "DomainAdmins" = "DomainAdmins"
}

# Gruppen-Konfiguration
$GroupsConfig = @{
    CreateDLGroups = $true  # Domain Local Groups erstellen
    CreateGLGroups = $true  # Global Groups erstellen
    DLSuffixes = @("Daten-L", "Daten-AE")  # Suffixe für DL-Gruppen
    Departments = @("Versand", "Vertrieb", "Gefue", "Shared", "DomainAdmins")
}

# OU-Struktur Konfiguration
$OUConfig = @{
    CreateExtendedStructure = $true  # Erweiterte OU-Struktur erstellen
    AdditionalOUs = @(
        @{ Name = "Gruppen"; Path = "OU=##COMPANY##,##DOMAIN##" },
        @{ Name = "Clients"; Path = "OU=##COMPANY##,##DOMAIN##" },
        @{ Name = "GL-Gruppen"; Path = "OU=Gruppen,OU=##COMPANY##,##DOMAIN##" },
        @{ Name = "DL-Gruppen"; Path = "OU=Gruppen,OU=##COMPANY##,##DOMAIN##" },
        @{ Name = "DomainAdmins"; Path = "OU=##COMPANY##,##DOMAIN##" }
    )
}

# ========================================================================
# SKRIPT-FUNKTIONEN
# ========================================================================

function Initialize-ADModule {
    Write-Host "Initialisiere Active Directory Modul..." -ForegroundColor Yellow
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Host "✓ ActiveDirectory Modul erfolgreich geladen" -ForegroundColor Green
    } catch {
        Write-Error "ActiveDirectory Modul konnte nicht geladen werden: $($_.Exception.Message)"
        exit 1
    }
}

function Set-ExecutionPolicyIfNeeded {
    $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($executionPolicy -ne "RemoteSigned") {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "✓ Execution Policy auf RemoteSigned gesetzt" -ForegroundColor Green
        } catch {
            Write-Error "Fehler beim Setzen der Execution Policy: $($_.Exception.Message)"
            exit 1
        }
    }
}

function New-OUStructure {
    param($Config)
    
    Write-Host "Erstelle OU-Struktur..." -ForegroundColor Yellow
    
    # Basis-OU erstellen
    $baseOU = "OU=$($Config.CompanyName),$($Config.DomainDN)"
    try {
        $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$baseOU'" -ErrorAction SilentlyContinue
        if (-not $existingOU) {
            New-ADOrganizationalUnit -Name $Config.CompanyName -Path $Config.DomainDN -ErrorAction Stop
            Write-Host "✓ Basis-OU erstellt: $($Config.CompanyName)" -ForegroundColor Green
        } else {
            Write-Host "! Basis-OU existiert bereits: $($Config.CompanyName)" -ForegroundColor Orange
        }
    } catch {
        Write-Host "! Fehler beim Erstellen der Basis-OU: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Abteilungs-OUs erstellen
    $uniqueOUs = $UsersConfig | Select-Object -ExpandProperty OUName -Unique
    foreach ($ouName in $uniqueOUs) {
        $ouPath = "OU=$ouName,OU=$($Config.CompanyName),$($Config.DomainDN)"
        try {
            $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouPath'" -ErrorAction SilentlyContinue
            if (-not $existingOU) {
                New-ADOrganizationalUnit -Name $ouName -Path "OU=$($Config.CompanyName),$($Config.DomainDN)" -ErrorAction Stop
                Write-Host "✓ Abteilungs-OU erstellt: $ouName" -ForegroundColor Green
            } else {
                Write-Host "! Abteilungs-OU existiert bereits: $ouName" -ForegroundColor Orange
            }
        } catch {
            Write-Host "! Fehler beim Erstellen der OU '$ouName': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Zusätzliche OUs erstellen (wenn aktiviert)
    if ($OUConfig.CreateExtendedStructure) {
        foreach ($ouEntry in $OUConfig.AdditionalOUs) {
            $ouName = $ouEntry.Name
            $parentPath = $ouEntry.Path -replace "##COMPANY##", $Config.CompanyName -replace "##DOMAIN##", $Config.DomainDN
            
            try {
                $existingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction SilentlyContinue | 
                              Where-Object { $_.DistinguishedName -like "*$parentPath" }
                if (-not $existingOU) {
                    New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
                    Write-Host "✓ Erweiterte OU erstellt: $ouName" -ForegroundColor Green
                } else {
                    Write-Host "! Erweiterte OU existiert bereits: $ouName" -ForegroundColor Orange
                }
            } catch {
                Write-Host "! Fehler beim Erstellen der erweiterten OU '$ouName': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

function New-SecurityGroups {
    param($Config)
    
    Write-Host "Erstelle Sicherheitsgruppen..." -ForegroundColor Yellow
    
    # Domain Local Groups erstellen
    if ($GroupsConfig.CreateDLGroups) {
        foreach ($department in $GroupsConfig.Departments) {
            foreach ($suffix in $GroupsConfig.DLSuffixes) {
                $groupName = "DL-$department-$suffix"
                try {
                    $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
                    if (-not $existingGroup) {
                        New-ADGroup -Name $groupName -GroupScope DomainLocal -GroupCategory Security -Path "OU=DL-Gruppen,OU=Gruppen,OU=$($Config.CompanyName),$($Config.DomainDN)" -ErrorAction Stop
                        Write-Host "✓ DL-Gruppe erstellt: $groupName" -ForegroundColor Green
                    } else {
                        Write-Host "! DL-Gruppe existiert bereits: $groupName" -ForegroundColor Orange
                    }
                } catch {
                    Write-Host "! Fehler beim Erstellen der DL-Gruppe '$groupName': $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Global Groups erstellen
    if ($GroupsConfig.CreateGLGroups) {
        foreach ($department in $GroupsConfig.Departments) {
            $groupName = "GL-$department"
            try {
                $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
                if (-not $existingGroup) {
                    New-ADGroup -Name $groupName -GroupScope Global -Path "OU=GL-Gruppen,OU=Gruppen,OU=$($Config.CompanyName),$($Config.DomainDN)" -ErrorAction Stop
                    Write-Host "✓ GL-Gruppe erstellt: $groupName" -ForegroundColor Green
                } else {
                    Write-Host "! GL-Gruppe existiert bereits: $groupName" -ForegroundColor Orange
                }
            } catch {
                Write-Host "! Fehler beim Erstellen der GL-Gruppe '$groupName': $(_Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

function New-DomainUsers {
    param($Config, $Users)
    
    Write-Host "Erstelle Domänen-Benutzer..." -ForegroundColor Yellow
    
    foreach ($user in $Users) {
        # Username generieren falls nicht angegeben
        $username = if ($user.Username) { $user.Username } else { "$($user.FirstName).$($user.LastName)".ToLower() }
        $fullName = $user.Name
        $userPrincipalName = "$username$($Config.DomainSuffix)"
        $userPath = "OU=$($user.OUName),OU=$($Config.CompanyName),$($Config.DomainDN)"
        
        try {
            $existingUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
            if (-not $existingUser) {
                New-ADUser -Name $fullName `
                          -GivenName $user.FirstName `
                          -Surname $user.LastName `
                          -SamAccountName $username `
                          -UserPrincipalName $userPrincipalName `
                          -Path $userPath `
                          -AccountPassword (ConvertTo-SecureString $Config.DefaultPassword -AsPlainText -Force) `
                          -Enabled $true `
                          -PasswordNeverExpires $true `
                          -ErrorAction Stop
                Write-Host "✓ Benutzer erstellt: $fullName ($username)" -ForegroundColor Green
            } else {
                Write-Host "! Benutzer existiert bereits: $username" -ForegroundColor Orange
            }
            
            # Gruppenzuordnung
            Add-UserToGroups -Username $username -Department $user.Department -SpecificPermissions $user.Permissions -Config $Config
            
        } catch {
            Write-Host "! Fehler beim Erstellen des Benutzers '$username': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Add-UserToGroups {
    param($Username, $Department, $SpecificPermissions, $Config)
    
    $adUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue
    if (-not $adUser) {
        Write-Host "! Benutzer '$Username' nicht gefunden für Gruppenzuordnung" -ForegroundColor Red
        return
    }
    
    # Abteilungsname mappen
    $mappedDept = if ($DepartmentMapping.ContainsKey($Department)) { $DepartmentMapping[$Department] } else { $Department }
    
    # Zur abteilungsspezifischen GL-Gruppe hinzufügen
    $deptGLGroup = "GL-$mappedDept"
    try {
        Add-ADGroupMember -Identity $deptGLGroup -Members $adUser -ErrorAction Stop
        Write-Host "  ✓ $Username zu GL-Gruppe hinzugefügt: $deptGLGroup" -ForegroundColor Green
    } catch {
        Write-Host "  ! Fehler beim Hinzufügen zu GL-Gruppe '$deptGLGroup': $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Zur GL-Shared Gruppe hinzufügen (alle Benutzer)
    try {
        Add-ADGroupMember -Identity "GL-Shared" -Members $adUser -ErrorAction Stop
        Write-Host "  ✓ $Username zu GL-Shared hinzugefügt" -ForegroundColor Green
    } catch {
        Write-Host "  ! Fehler beim Hinzufügen zu GL-Shared: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Spezifische Berechtigungen hinzufügen
    foreach ($permission in $SpecificPermissions) {
        try {
            $group = Get-ADGroup -Filter "Name -eq '$permission'" -ErrorAction SilentlyContinue
            if ($group) {
                Add-ADGroupMember -Identity $permission -Members $adUser -ErrorAction Stop
                Write-Host "  ✓ $Username zu spezifischer Gruppe hinzugefügt: $permission" -ForegroundColor Green
            } else {
                Write-Host "  ! Gruppe '$permission' existiert nicht" -ForegroundColor Orange
            }
        } catch {
            Write-Host "  ! Fehler beim Hinzufügen zu '$permission': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Set-GroupNesting {
    param($Config)
    
    Write-Host "Konfiguriere Gruppen-Nesting (ADGLP)..." -ForegroundColor Yellow
    
    foreach ($department in $GroupsConfig.Departments) {
        $glGroupName = "GL-$department"
        $glGroup = Get-ADGroup -Filter "Name -eq '$glGroupName'" -ErrorAction SilentlyContinue
        
        if (-not $glGroup) {
            Write-Host "! GL-Gruppe '$glGroupName' nicht gefunden" -ForegroundColor Orange
            continue
        }
        
        # Bestimme Suffixe basierend auf Abteilung
        $suffixes = switch ($department) {
            "Versand" { @("Daten-L") }
            "Shared" { @("Daten-AE") }
            default { @("Daten-AE", "Daten-L") }
        }
        
        foreach ($suffix in $suffixes) {
            $dlGroupName = "DL-$department-$suffix"
            try {
                $dlGroup = Get-ADGroup -Filter "Name -eq '$dlGroupName'" -ErrorAction SilentlyContinue
                if ($dlGroup) {
                    Add-ADGroupMember -Identity $dlGroupName -Members $glGroupName -ErrorAction Stop
                    Write-Host "✓ GL-Gruppe '$glGroupName' zu DL-Gruppe '$dlGroupName' hinzugefügt" -ForegroundColor Green
                } else {
                    Write-Host "! DL-Gruppe '$dlGroupName' nicht gefunden" -ForegroundColor Orange
                }
            } catch {
                Write-Host "! Fehler beim Nesting '$glGroupName' -> '$dlGroupName': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Spezielle Berechtigungen: GL-Gefue auch in DL-Versand-Daten-AE
    try {
        $dlVersandAE = Get-ADGroup -Filter "Name -eq 'DL-Versand-Daten-AE'" -ErrorAction SilentlyContinue
        $glGefue = Get-ADGroup -Filter "Name -eq 'GL-Gefue'" -ErrorAction SilentlyContinue
        if ($dlVersandAE -and $glGefue) {
            Add-ADGroupMember -Identity $dlVersandAE -Members $glGefue -ErrorAction Stop
            Write-Host "✓ Spezielle Berechtigung: GL-Gefue zu DL-Versand-Daten-AE hinzugefügt" -ForegroundColor Green
        }
    } catch {
        Write-Host "! Fehler bei spezieller Berechtigung: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ========================================================================
# HAUPTAUSFÜHRUNG
# ========================================================================

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "ERWEITERTE AD-KONFIGURATION MIT ADGLP-PRINZIP" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "Firma: $($DomainConfig.CompanyName)" -ForegroundColor White
Write-Host "Domain: $($DomainConfig.DomainDN)" -ForegroundColor White
Write-Host "Benutzer: $($UsersConfig.Count)" -ForegroundColor White
Write-Host "========================================================================" -ForegroundColor Cyan

# Initialisierung
Initialize-ADModule
Set-ExecutionPolicyIfNeeded

# Strukturen erstellen
New-OUStructure -Config $DomainConfig
New-SecurityGroups -Config $DomainConfig
New-DomainUsers -Config $DomainConfig -Users $UsersConfig
Set-GroupNesting -Config $DomainConfig

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "KONFIGURATION ABGESCHLOSSEN!" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "✓ OU-Struktur erstellt" -ForegroundColor Green
Write-Host "✓ Sicherheitsgruppen konfiguriert" -ForegroundColor Green
Write-Host "✓ Benutzer erstellt und zugeordnet" -ForegroundColor Green
Write-Host "✓ ADGLP-Prinzip implementiert" -ForegroundColor Green
Write-Host "Standard-Passwort: $($DomainConfig.DefaultPassword)" -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Cyan
