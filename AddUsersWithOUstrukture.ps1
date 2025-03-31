# Stellen Sie sicher, dass das Active Directory-Modul geladen ist
Import-Module ActiveDirectory

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
    @{Name="Ute Unten"; Permissions=@("DL-Versand-Read", "DL-Versand-Write")},
    @{Name="Max Mitte"; Permissions=@("DL-Vertrieb-Read")},
    @{Name="Olaf Oben"; Permissions=@("DL-Geschaeftsfuehrung-Full")}
)

# Konvertiere Benutzerberechtigungen in ein Hashtable für schnelleren Zugriff
$userPermissions = @{}
foreach ($entry in $userPermissionsArray) {
    $userPermissions[$entry.Name] = $entry.Permissions
}

# Lokale Domaenengruppen erstellen (nur Read, Write, Full pro Abteilung)
$departments = @("Buchhaltung", "Marketing", "IT", "Versand-Abt", "Vertrieb-Abt", "Gefue-Abt")
foreach ($department in $departments) {
    foreach ($suffix in @("Read", "Write", "Full")) {
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
    $username = ("$firstName$lastName").Trim()  # Änderung: Kein Punkt
     
    $password = "Password1"  # Sicherste Passwort der Welt
    $ou = $user.OU
    $userPrincipalName = "$username@technotrans.dom"
    
    if (-not (Get-ADUser -Filter {SamAccountName -eq $username})) {
        Write-Host "Erstelle Benutzer: $cleanFullName"
        New-ADUser @{
            Name               = $cleanFullName
            GivenName          = $firstName
            Surname            = $lastName
            SamAccountName     = $username
            UserPrincipalName  = $userPrincipalName
            Path               = $ou
            AccountPassword    = (ConvertTo-SecureString -AsPlainText $password -Force)
            Enabled            = $true
            PasswordNeverExpires = $true
        }
    } else {
        Write-Host "Benutzer $username existiert bereits."
    }
    $adUser = Get-ADUser -Filter {SamAccountName -eq $username}
    
    if ($adUser) {
        # Sicherstellen, dass die Abteilungsgruppe existiert, z.B. "Versand-Group"
        $deptGroup = "$($user.Department)-Group"
        if (-not (Get-ADGroup -Filter {Name -eq $deptGroup})) {
            Write-Host "Erstelle Gruppe: $deptGroup"
            New-ADGroup -Name $deptGroup -GroupScope Global -Path "OU=GL-Gruppen,OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"
        }
    
        # Benutzer der Abteilungsgruppe hinzufügen
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
        Write-Host "Benutzererstellung fehlgeschlagen für $username. Gruppenzuordnung wird uebersprungen."
    }
}

# Neue Schleife zum Hinzufuegen der DL Gruppen als Mitglieder der entsprechenden GL Gruppen
$departmentsForNesting = @("Buchhaltung", "Marketing", "IT", "Versand-Abt", "Vertrieb-Abt", "Gefue-Abt")
foreach ($department in $departmentsForNesting) {
    $glGroup = "$department-Group"
    foreach ($suffix in @("Read", "Write", "Full")) {
        $dlGroup = "DL-$department-$suffix"
        if ((Get-ADGroup -Filter {Name -eq $dlGroup}) -and (Get-ADGroup -Filter {Name -eq $glGroup})) {
            Write-Host "Fuege DL Gruppe $dlGroup zur GL Gruppe $glGroup hinzu"
            Add-ADGroupMember -Identity $glGroup -Members $dlGroup
        }
    }
}