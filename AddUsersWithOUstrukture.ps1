# Stellen Sie sicher, dass das Active Directory-Modul geladen ist
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Warning "ActiveDirectory Modul nicht verfuegbar  Dummy-Implementierungen werden genutzt."
}

$ExecutionPolicy = Get-ExecutionPolicy
if ($ExecutionPolicy -ne "RemoteSigned") {
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
}

# Benutzer anlegen und OUs erstellen 
$users = @(
    @{Name="Ute Unten"; Department="Versand"; OU="OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Max Mitte"; Department="Vertrieb"; OU="OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Olaf Oben"; Department="Geschaeftsfuehrung"; OU="OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"}
)



# OUs erstellen
$ouStructure = @(
    "OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"
)

foreach ($ou in $ouStructure) {
    if (-not (Get-ADOrganizationalUnit -Filter {DistinguishedName -eq $ou})) {
        $ouName = $ou.Split(',')[0] -replace 'OU=', ''
        New-ADOrganizationalUnit -Name $ouName -Path ($ou -replace '^OU=.*?,', '')
    }
}

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
$departments = @(<#"Buchhaltung", "Marketing", "IT",#>"Versand", "Vertrieb", "Gefue", "Shared")
foreach ($department in $departments) {
    foreach ($suffix in @("-Daten-L", "-Daten-AE")) {
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
}