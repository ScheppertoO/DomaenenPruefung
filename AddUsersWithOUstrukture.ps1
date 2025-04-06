<# # nurfür Referenzen 1.Test skript
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "ActiveDirectory Modul erfolgreich geladen."
} catch {
    Write-Error "ActiveDirectory Modul konnte nicht geladen werden. Bitte stellen Sie sicher, dass es installiert ist."
    exit 1
}

# Pruefen und setzen der Execution Policy (nur wenn nicht bereits RemoteSigned)
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -ne "RemoteSigned") {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Verbose "Execution Policy wurde auf RemoteSigned gesetzt."
    } catch {
        Write-Error "Fehler beim Setzen der Execution Policy. Bitte ueberpruefen Sie Ihre Berechtigungen."
        exit 1
    }
}


# Benutzer anlegen und OUs erstellen 
$users = @(
    @{Name="Ute Unten"; Department="Versand"; OU="OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Max Mitte"; Department="Vertrieb"; OU="OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Olaf Oben"; Department="Geschaeftsfuehrung"; OU="OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"}
)


##############################################################
# OUs erstellen
$ouStructure = @(
    "OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"
)

foreach ($ou in $ouStructure) {
    Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" {
        $ouName = $ou.Split(',')[0] -replace 'OU=', ''
        New-ADOrganizationalUnit -Name $ouName -Path ($ou -replace '^OU=.*?,', '')
    }
}
##############################################################
# Basis-OU-Struktur erstellen
$ouStructure = @(
    "OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"
)

foreach ($ou in $ouStructure) {
    $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" -ErrorAction SilentlyContinue
    if (-not $existingOU) {
        $ouName = ($ou -split ",")[0] -replace 'OU='
        $parentPath = $ou -replace "^OU=[^,]+,", ""
        try {
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
            Write-Verbose "OU '$ouName' wurde erfolgreich unter '$parentPath' erstellt."
        } catch {
            Write-Error "Fehler beim Erstellen der OU '$ouName' unter '$parentPath': $_"
        }
    } else {
        Write-Verbose "OU existiert bereits: $ou"
    }
}

# Weitere OUs (z. B. Gruppen und Clients) erstellen, falls nicht vorhanden
$additionalOUs = @(
    @{ Name = "Gruppen"; Path = "OU=Technotrans,DC=Technotrans,DC=dom" },
    @{ Name = "Clients"; Path = "OU=Technotrans,DC=Technotrans,DC=dom" },
    @{ Name = "GL-Gruppen"; Path = "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" },
    @{ Name = "DL-Gruppen"; Path = "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" }
)

foreach ($ouEntry in $additionalOUs) {
    $ouName = $ouEntry.Name
    $parentPath = $ouEntry.Path
    $existingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName' -and DistinguishedName -like '*$parentPath'" -ErrorAction SilentlyContinue
    if (-not $existingOU) {
        try {
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
            Write-Verbose "OU '$ouName' wurde erfolgreich unter '$parentPath' erstellt."
        } catch {
            Write-Error "Fehler beim Erstellen der OU '$ouName' unter '$parentPath': $_"
        }
    } else {
        Write-Verbose "OU '$ouName' existiert bereits unter '$parentPath'."
    }
}

########################################################DL-Firmendaten-L FEHLT######################################################

New-ADOrganizationalUnit -Name Gruppen -Path "OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name Clients -Path "OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name GL-Gruppen -Path "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name DL-Gruppen -Path "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"

# Benutzerberechtigungen definieren
$userPermissionsArray = @(
    @{Name="Ute Unten"; Permissions=@("DL-Versand-Daten-R")},
    @{Name="Max Mitte"; Permissions=@("DL-Vertrieb-Daten-AE")},
    @{Name="Olaf Oben"; Permissions=@("DL-Gefue-Daten-AE", "DL-Versand-Daten-R")}
)

# Konvertiere Benutzerberechtigungen in ein Hashtable fuer schnelleren Zugriff
$userPermissions = @{}
foreach ($entry in $userPermissionsArray) {
    $userPermissions[$entry.Name] = $entry.Permissions
}

# Lokale Domaenengruppen erstellen (nur Read, Write, Full pro Abteilung)
$departments = @("Versand", "Vertrieb", "Gefue", "Shared")
foreach ($department in $departments) {
    foreach ($suffix in @("Daten-L", "Daten-AE")) {
        $groupName = "DL-$department-$suffix"
        Write-Host "Pruefe lokale Domaenengruppe: $groupName"
        if (-not (Get-ADGroup -Filter {Name -eq $groupName})) {
            Write-Host "Erstelle lokale Domaenengruppe: $groupName"
            New-ADGroup -Name $groupName -GroupScope DomainLocal -GroupCategory Security -Path "OU=DL-Gruppen,OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"
        } else {
            Write-Host "Lokale Domaenengruppe existiert bereits: $groupName"
        }
   }
}

########################################################################################################
# Benutzer anlegen und zu den entsprechenden Gruppen hinzufuegen
foreach ($user in $users) {
    $cleanFullName = $user.Name.Trim()
    $nameParts = $cleanFullName.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $firstName = $nameParts[0].Trim()
    $lastName = if ($nameParts.Count -ge 2) { $nameParts[1].Trim() } else { "" }
    $username = ("$firstName$lastName").Trim()  # aenderung: Kein Punkt
     
    $password = "Password1"  # Sicherste Passwort der Welt
    $ou = $user.OU
    $userPrincipalName = "$username@technotrans.dom"

    Write-Host "=== DEBUG: Variablen fuer Benutzer $cleanFullName ===" -ForegroundColor Cyan
    Write-Host "firstName: $firstName" -ForegroundColor Gray
    Write-Host "lastName: $lastName" -ForegroundColor Gray
    Write-Host "username: $username" -ForegroundColor Gray
    Write-Host "ou: $ou" -ForegroundColor Gray
    Write-Host "userPrincipalName: $userPrincipalName" -ForegroundColor Gray
    
    if (-not (Get-ADUser -Filter {SamAccountName -eq $username})) {
        Write-Host "Erstelle Benutzer: $cleanFullName"
        New-ADUser -Name $cleanFullName `
                  -GivenName $firstName `
                  -Surname $lastName `
                  -SamAccountName $username `
                  -UserPrincipalName $userPrincipalName `
                  -Path $ou `
                  -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) `
                  -Enabled $true `
                  -PasswordNeverExpires $true
    } else {
        Write-Host "Benutzer $username existiert bereits."
    }
    $adUser = Get-ADUser -Filter {SamAccountName -eq $username}
    
    Write-Host "=== DEBUG: ADUser Objekt ===" -ForegroundColor Cyan
    Write-Host "adUser: $adUser" -ForegroundColor Gray
    if ($adUser) {
        Write-Host "  DistinguishedName: $($adUser.DistinguishedName)" -ForegroundColor Gray
        Write-Host "  SamAccountName: $($adUser.SamAccountName)" -ForegroundColor Gray
        Write-Host "  UserPrincipalName: $($adUser.UserPrincipalName)" -ForegroundColor Gray
        Write-Host "  Enabled: $($adUser.Enabled)" -ForegroundColor Gray
    } else {
        Write-Host "  adUser ist NULL oder leer!" -ForegroundColor Red
    }
    
    if ($adUser) {
        # Sicherstellen, dass die Abteilungsgruppe existiert, z.B. "Versand-Group"
        $deptGroup = "GL-$($user.Department)"
        Write-Host "=== DEBUG: Gruppenvariablen ===" -ForegroundColor Cyan
        Write-Host "deptGroup: $deptGroup" -ForegroundColor Gray
        Write-Host "Department: $($user.Department)" -ForegroundColor Gray        # Sicherstellen, dass die Abteilungsgruppe existiert, z.B. "GL-Versand"
        $deptGroup = "GL-$($user.Department)"
        if (-not (Get-ADGroup -Filter {Name -eq $deptGroup})) {
            Write-Host "Erstelle Gruppe: $deptGroup"
            New-ADGroup -Name $deptGroup -GroupScope Global -Path "OU=GL-Gruppen,OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"
        }
    
        # Benutzer der Abteilungsgruppe hinzufuegen
        Write-Host "Fuege Benutzer $username zu Gruppe $deptGroup hinzu"
        Add-ADGroupMember -Identity $deptGroup -Members $adUser
    
        # Benutzerberechtigungen auslesen und zu den entsprechenden Gruppen hinzufuegen
        if ($userPermissions.ContainsKey($user.Name)) {
            foreach ($permissionGroup in $userPermissions[$user.Name]) {
                Write-Host "Fuege Benutzer $username zu Gruppe $permissionGroup hinzu"
                if (Get-ADGroup -Filter {Name -eq $permissionGroup}) {
                    Add-ADGroupMember -Identity $permissionGroup -Members $adUser
                } else {
                    Write-Host "Gruppe $permissionGroup existiert nicht. Ueberspringe Hinzufuegen."
                }
            }
        } else {
            Write-Host "Keine spezifischen Berechtigungen fuer Benutzer $username gefunden."
        }
    }
    else {
        Write-Host "Benutzererstellung fehlgeschlagen fuer $username. Gruppenzuordnung wird uebersprungen."
    }
}

# Schleife zum Hinzufuegen der GL Gruppen als Mitglieder der entsprechenden DL Gruppen
# (Umkehrung der vorherigen Logik - Global Groups muessen in Domain Local Groups sein, nicht umgekehrt)
$departmentsForNesting = @("Versand", "Vertrieb", "Gefue", "Shared")
foreach ($department in $departmentsForNesting) {
    $glGroup = "GL-$department"
    foreach ($suffix in @("Daten-AE", "Daten-L")) {
        $dlGroup = "DL-$department-$suffix"
        if ((Get-ADGroup -Filter {Name -eq $dlGroup}) -and (Get-ADGroup -Filter {Name -eq $glGroup})) {
            Write-Host "Fuege GL Gruppe $glGroup zur DL Gruppe $dlGroup hinzu"
            Add-ADGroupMember -Identity $dlGroup -Members $glGroup
        }
    }
} #>

# ========================================================================
# Modul-Import und Execution Policy
# ========================================================================
# ========================================================================
# Modul-Import und Execution Policy
# ========================================================================
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "ActiveDirectory Modul erfolgreich geladen."
} catch {
    Write-Error "ActiveDirectory Modul konnte nicht geladen werden. Bitte stellen Sie sicher, dass es installiert ist."
    exit 1
}

$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -ne "RemoteSigned") {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Verbose "Execution Policy wurde auf RemoteSigned gesetzt."
    } catch {
        Write-Error "Fehler beim Setzen der Execution Policy. Bitte überprüfen Sie Ihre Berechtigungen."
        exit 1
    }
}

# ========================================================================
# Definition der Benutzer und Abteilungs-Mapping
# ========================================================================
# Mapping: Wenn im Benutzerobjekt "Geschaeftsfuehrung" steht, soll intern "Gefue" genutzt werden
$deptMapping = @{
    "Geschaeftsfuehrung" = "Gefue"
}

$users = @(
    @{Name="Ute Unten"; Department="Versand"; OU="OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Max Mitte"; Department="Vertrieb"; OU="OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Olaf Oben"; Department="Geschaeftsfuehrung"; OU="OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"}
)

# ========================================================================
# Erstellung der Basis-OU-Struktur
# ========================================================================
$ouStructure = @(
    "OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"
)

foreach ($ou in $ouStructure) {
    $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" -ErrorAction SilentlyContinue
    if (-not $existingOU) {
        $ouName = ($ou -split ",")[0] -replace 'OU='
        $parentPath = $ou -replace "^OU=[^,]+,", ""
        try {
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
            Write-Verbose "OU '$ouName' wurde erfolgreich unter '$parentPath' erstellt."
        } catch {
            if ($_.Exception.Message -match "bereits verwendet") {
                Write-Verbose "OU '$ouName' existiert bereits unter '$parentPath'."
            } else {
                Write-Error "Fehler beim Erstellen der OU '$ouName' unter '$parentPath': $_"
            }
        }
    } else {
        Write-Verbose "OU existiert bereits: $ou"
    }
}

# ========================================================================
# Erstellung zusätzlicher OUs (Gruppen, Clients, etc.)
# ========================================================================
$additionalOUs = @(
    @{ Name = "Gruppen"; Path = "OU=Technotrans,DC=Technotrans,DC=dom" },
    @{ Name = "Clients"; Path = "OU=Technotrans,DC=Technotrans,DC=dom" },
    @{ Name = "GL-Gruppen"; Path = "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" },
    @{ Name = "DL-Gruppen"; Path = "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" }
)

foreach ($ouEntry in $additionalOUs) {
    $ouName = $ouEntry.Name
    $parentPath = $ouEntry.Path
    $existingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction SilentlyContinue | Where-Object { $_.DistinguishedName -like "*$parentPath" }
    if (-not $existingOU) {
        try {
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
            Write-Verbose "OU '$ouName' wurde erfolgreich unter '$parentPath' erstellt."
        } catch {
            if ($_.Exception.Message -match "bereits verwendet") {
                Write-Verbose "OU '$ouName' existiert bereits unter '$parentPath'."
            } else {
                Write-Error "Fehler beim Erstellen der OU '$ouName' unter '$parentPath': $_"
            }
        }
    } else {
        Write-Verbose "OU '$ouName' existiert bereits unter '$parentPath'."
    }
}

# ========================================================================
# Erstellung lokaler Domain-Gruppen (Domain Local Groups)
# ========================================================================
$departmentsForDL = @("Versand", "Vertrieb", "Gefue", "Shared")
foreach ($department in $departmentsForDL) {
    foreach ($suffix in @("Daten-L", "Daten-AE")) {
        $groupName = "DL-$department-$suffix"
        Write-Verbose "Prüfe lokale Domain-Gruppe: $groupName"
        if (-not (Get-ADGroup -Filter "Name -eq '$groupName'")) {
            try {
                New-ADGroup -Name $groupName -GroupScope DomainLocal -GroupCategory Security -Path "OU=DL-Gruppen,OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" -ErrorAction Stop
                Write-Verbose "Erstelle lokale Domain-Gruppe: $groupName"
            } catch {
                Write-Error "Fehler beim Erstellen der Domain-Gruppe '$groupName': $_"
            }
        } else {
            Write-Verbose "Lokale Domain-Gruppe existiert bereits: $groupName"
        }
    }
}

# ========================================================================
# Sicherstellen, dass GL-Gruppen für alle Abteilungen existieren (inkl. Shared)
# ========================================================================
$departmentsForGL = @("Versand", "Vertrieb", "Gefue", "Shared")
foreach ($dept in $departmentsForGL) {
    $glGroupName = "GL-$dept"
    $existingGLGroup = Get-ADGroup -Filter "Name -eq '$glGroupName'" -ErrorAction SilentlyContinue
    if (-not $existingGLGroup) {
        try {
            New-ADGroup -Name $glGroupName -GroupScope Global -Path "OU=GL-Gruppen,OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" -ErrorAction Stop
            Write-Verbose "GL-Gruppe '$glGroupName' wurde erstellt (automatisch)."
        } catch {
            Write-Error "Fehler beim Erstellen der GL-Gruppe '$glGroupName': $_"
        }
    } else {
        Write-Verbose "GL-Gruppe '$glGroupName' existiert bereits."
    }
}

# ========================================================================
# Benutzer anlegen und zu GL-Gruppen hinzufügen (ADGLP-Prinzip)
# ========================================================================
foreach ($user in $users) {
    $cleanFullName = $user.Name.Trim()
    $nameParts = $cleanFullName.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $firstName = $nameParts[0].Trim()
    $lastName = if ($nameParts.Count -ge 2) { $nameParts[1].Trim() } else { "" }
    $username = ("$firstName$lastName").ToLower()

    # Hinweis: Für produktiven Einsatz ein sicheres, zufälliges Passwort oder Parameterübergabe nutzen
    $password = "Password1"  
    $ou = $user.OU
    $userPrincipalName = "$username@technotrans.dom"

    Write-Verbose "Verarbeite Benutzer: $cleanFullName mit SamAccountName: $username in OU: $ou"

    $existingUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
    if (-not $existingUser) {
        try {
            New-ADUser -Name $cleanFullName `
                       -GivenName $firstName `
                       -Surname $lastName `
                       -SamAccountName $username `
                       -UserPrincipalName $userPrincipalName `
                       -Path $ou `
                       -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) `
                       -Enabled $true `
                       -PasswordNeverExpires $true -ErrorAction Stop
            Write-Verbose "Benutzer '$username' erfolgreich erstellt."
        } catch {
            Write-Error "Fehler beim Erstellen des Benutzers '$username': $_"
            continue
        }
    } else {
        Write-Verbose "Benutzer '$username' existiert bereits."
    }

    $adUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue

    if ($adUser) {
        Write-Verbose "Benutzerobjekt gefunden: $($adUser.DistinguishedName)"
        
        # Abteilungsname angleichen – Mapping nutzen, falls vorhanden
        $deptKey = $user.Department
        if ($deptMapping.ContainsKey($deptKey)) {
            $deptKey = $deptMapping[$deptKey]
        }
        
        # Ermitteln der abteilungsspezifischen GL-Gruppe (z.B. GL-Versand)
        $deptGLGroup = "GL-$deptKey"
        $existingGroup = Get-ADGroup -Filter "Name -eq '$deptGLGroup'" -ErrorAction SilentlyContinue
        if (-not $existingGroup) {
            try {
                New-ADGroup -Name $deptGLGroup -GroupScope Global -Path "OU=GL-Gruppen,OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom" -ErrorAction Stop
                Write-Verbose "GL-Gruppe '$deptGLGroup' wurde erstellt."
            } catch {
                Write-Error "Fehler beim Erstellen der GL-Gruppe '$deptGLGroup': $_"
            }
        } else {
            Write-Verbose "GL-Gruppe '$deptGLGroup' existiert bereits."
        }

        # Benutzer der abteilungsspezifischen GL-Gruppe hinzufügen
        try {
            Add-ADGroupMember -Identity $deptGLGroup -Members $adUser -ErrorAction Stop
            Write-Verbose "Benutzer '$username' wurde der GL-Gruppe '$deptGLGroup' hinzugefügt."
        } catch {
            Write-Error "Fehler beim Hinzufügen von '$username' zur GL-Gruppe '$deptGLGroup': $_"
        }
        
        # Zusätzlich: Alle Benutzer auch in GL-Shared aufnehmen
        try {
            Add-ADGroupMember -Identity "GL-Shared" -Members $adUser -ErrorAction Stop
            Write-Verbose "Benutzer '$username' wurde der GL-Gruppe 'GL-Shared' hinzugefügt."
        } catch {
            Write-Error "Fehler beim Hinzufügen von '$username' zur GL-Gruppe 'GL-Shared': $_"
        }
    } else {
        Write-Error "Benutzer '$username' konnte nicht erstellt werden. Überspringe Gruppenzuordnung."
    }
}

# ========================================================================
# Gruppen-Nesting: Hinzufügen von GL-Gruppen zu den DL-Gruppen (ADGLP-Prinzip)
# ========================================================================
$departmentsForNesting = @("Versand", "Vertrieb", "Gefue", "Shared")
foreach ($department in $departmentsForNesting) {
    $glGroupName = "GL-$department"
    $glGroup = Get-ADGroup -Filter "Name -eq '$glGroupName'" -ErrorAction SilentlyContinue
    if (-not $glGroup) {
        Write-Warning "GL-Gruppe '$glGroupName' existiert nicht. Überspringe Abteilung '$department'."
        continue
    }
    # Auswahl der Suffixe:
    # Für 'Versand' sollen nur die DL-Gruppen mit Lese-Rechten ("Daten-L") genutzt werden,
    # für 'Shared' nur "Daten-AE",
    # für die übrigen Abteilungen beide.
    if ($department -eq "Versand") {
        $suffixes = @("Daten-L")
    } elseif ($department -eq "Shared") {
        $suffixes = @("Daten-AE")
    } else {
        $suffixes = @("Daten-AE", "Daten-L")
    }
    foreach ($suffix in $suffixes) {
        $dlGroupName = "DL-$department-$suffix"
        $dlGroup = Get-ADGroup -Filter "Name -eq '$dlGroupName'" -ErrorAction SilentlyContinue
        if ($dlGroup) {
            try {
                Add-ADGroupMember -Identity $dlGroupName -Members $glGroupName -ErrorAction Stop
                Write-Verbose "GL-Gruppe '$glGroupName' wurde zur DL-Gruppe '$dlGroupName' hinzugefügt."
            } catch {
                Write-Error "Fehler beim Hinzufügen von '$glGroupName' zu '$dlGroupName': $_"
            }
        } else {
            Write-Warning "DL-Gruppe '$dlGroupName' existiert nicht. Überspringe."
        }
    }
}

# ========================================================================
# Zusätzlich: GL-Gefue (Geschäftsführer) soll in DL-Versand-Daten-AE aufgenommen werden,
# damit der Geschäftsführer auf dem Versand-Ordner Änderungsrechte erhält.
# ========================================================================
$dlVersandAE = Get-ADGroup -Filter "Name -eq 'DL-Versand-Daten-AE'" -ErrorAction SilentlyContinue
$glGefue = Get-ADGroup -Filter "Name -eq 'GL-Gefue'" -ErrorAction SilentlyContinue
if ($dlVersandAE -and $glGefue) {
    try {
         Add-ADGroupMember -Identity $dlVersandAE -Members $glGefue -ErrorAction Stop
         Write-Verbose "GL-Gefue wurde zur DL-Versand-Daten-AE hinzugefügt."
    } catch {
         Write-Error "Fehler beim Hinzufügen von GL-Gefue zu DL-Versand-Daten-AE: $_"
    }
} else {
    Write-Warning "Entweder DL-Versand-Daten-AE oder GL-Gefue existiert nicht."
}
