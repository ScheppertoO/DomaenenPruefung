# Stellen Sie sicher, dass das Active Directory-Modul geladen ist
Import-Module ActiveDirectory

$ExecutionPolicy = Get-ExecutionPolicy
if ($ExecutionPolicy -ne "RemoteSigned") {
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
}

# Benutzer anlegen und OUs erstellen 
$users = @(
    @{Name="Udo Unten"; Department="Versand"; OU="OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Max Mitte"; Department="Vertrieb"; OU="OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom"},
    @{Name="Olaf Oben"; Department="Geschäftsführung"; OU="OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"}
)



# OUs erstellen
$ouStructure = @(
    "OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom",
    "OU=Gefue-Abt,OU=Technotrans,DC=Technotrans,DC=dom"
)

foreach ($ou in $ouStructure) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$($ou)'")) {
        $ouName = $ou.Split(',')[0] -replace 'OU=', ''
        New-ADOrganizationalUnit -Name $ouName -Path ($ou -replace '^OU=.*?,', '')
    }
}

New-ADOrganizationalUnit -Name Gruppen -Path "OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name Clients -Path "OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name GL-Gruppen -Path "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name DL-Gruppen -Path "OU=Gruppen,OU=Technotrans,DC=Technotrans,DC=dom"

<# Alter Weg 
foreach ($user in $users) {
    # Benutzer erstellen, falls nicht bereits vorhanden
    if (-not (Get-ADUser -Filter "Name -eq '$($user.Name)'")) {
        New-ADUser -Name $user.Name -Department $user.Department -Path $user.OU -AccountPassword (ConvertTo-SecureString "Passwort123!" -AsPlainText -Force) -Enabled $true
    }
    
    # Überprüfen, ob die Abteilung eine entsprechende Gruppe hat
    if ($departmentGroupMapping.ContainsKey($user.Department)) {
        $groupName = $departmentGroupMapping[$user.Department]

        # Überprüfen, ob die Gruppe existiert, und erstellen, falls nicht
        if (-not (Get-ADGroup -Filter "Name -eq '$groupName'")) {
            New-ADGroup -Name $groupName -GroupScope Global -Path "OU=Groups,DC=Technotrans,DC=dom"
        }

        # Benutzer der Gruppe hinzufügen
        Add-ADGroupMember -Identity $groupName -Members $user.Name
    }
}


# Globale Gruppen erstellen
$globalGroups = @("GL-Buchhaltung-Group", "GL-Marketing-Group", "GL-IT-Group")
foreach ($group in $globalGroups) {
    Write-Host "Prüfe Gruppe: $group"
    if (-not (Get-ADGroup -Filter {Name -eq $group})) {
        Write-Host "Erstelle Gruppe: $group"
        New-ADGroup -Name $group -GroupScope Global -Path "DC=demo,DC=dom"
    } else {
        Write-Host "Gruppe existiert bereits: $group"
    }
}

# Benutzer anlegen und zu globalen Gruppen hinzufügen
foreach ($user in $users) {
    $username = $user.Name -replace " ", "."
    $password = "Password1"  # Sicherste Passwort der Welt
    $ou = $user.OU
    $userPrincipalName = "$username@demo.dom"

    Write-Host "Erstelle Benutzer: $user.Name"
    New-ADUser -Name $user.Name -GivenName $user.Name.Split(" ")[0] -Surname $user.Name.Split(" ")[1] `
               -SamAccountName $username -UserPrincipalName $userPrincipalName `
               -Path $ou -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -Enabled $true -PasswordNeverExpires $true

    # Benutzer zu globalen Gruppen hinzufügen
    Write-Host "Füge Benutzer $username zu Gruppe $($user.Department)-Group hinzu"
    Add-ADGroupMember -Identity "$($user.Department)-Group" -Members $username
}

# Lokale Domänengruppen erstellen und globale Gruppen hinzufügen
$domainLocalGroups = @("DL-Buchhaltung-Daten", "DL-Marketing-Daten", "DL-IT-Daten")
foreach ($group in $domainLocalGroups) {
    Write-Host "Prüfe lokale Domänengruppe: $group"
    if (-not (Get-ADGroup -Filter {Name -eq $group})) {
        Write-Host "Erstelle lokale Domänengruppe: $group"
        New-ADGroup -Name $group -GroupScope DomainLocal -Path "DC=demo,DC=dom"
    } else {
        Write-Host "Lokale Domänengruppe existiert bereits: $group"
    }

    # Globale Gruppe zu lokaler Domänengruppe hinzufügen
    if ($group -eq "DL-Buchhaltung-Daten") {
        Write-Host "Füge GL-Buchhaltung-Group zu $group hinzu"
        Add-ADGroupMember -Identity $group -Members "GL-Buchhaltung-Group"
    } elseif ($group -eq "DL-Marketing-Daten") {
        Write-Host "Füge GL-Marketing-Group zu $group hinzu"
        Add-ADGroupMember -Identity $group -Members "GL-Marketing-Group"
    } elseif ($group -eq "DL-IT-Daten") {
        Write-Host "Füge GL-IT-Group zu $group hinzu"
        Add-ADGroupMember -Identity $group -Members "GL-IT-Group"
    }
}
    #>
# Benutzerberechtigungen definieren
$userPermissions = @(
    @{Name="Udo Unten"; Permissions=@("DL-Versand-Read", "DL-Versand-Write")},
    @{Name="Max Mitte"; Permissions=@("DL-Vertrieb-Read")},
    @{Name="Olaf Oben"; Permissions=@("DL-Geschäftsführung-Full")}
)

# Lokale Domänengruppen erstellen (nur Read, Write, Full pro Abteilung)
$departments = @("Buchhaltung", "Marketing", "IT", "Versand", "Vertrieb", "Geschäftsführung")
foreach ($department in $departments) {
    foreach ($suffix in @("Read", "Write", "Full")) {
        $groupName = "DL-$department-$suffix"
        Write-Host "Prüfe lokale Domänengruppe: $groupName"
        if (-not (Get-ADGroup -Filter {Name -eq $groupName})) {
            Write-Host "Erstelle lokale Domänengruppe: $groupName"
            New-ADGroup -Name $groupName -GroupScope DomainLocal -Path "DC=demo,DC=dom"
        } else {
            Write-Host "Lokale Domänengruppe existiert bereits: $groupName"
        }
    }
}

# Benutzer anlegen und zu den entsprechenden Gruppen hinzufügen
foreach ($user in $users) {
    $username = $user.Name -replace " ", "."
    $password = "Password1"  # Sicherste Passwort der Welt
    $ou = $user.OU
    $userPrincipalName = "$username@demo.dom"

    Write-Host "Erstelle Benutzer: $user.Name"
    New-ADUser -Name $user.Name -GivenName $user.Name.Split(" ")[0] -Surname $user.Name.Split(" ")[1] `
               -SamAccountName $username -UserPrincipalName $userPrincipalName `
               -Path $ou -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -Enabled $true -PasswordNeverExpires $true

    # Benutzer zu globalen Gruppen hinzufügen
    Write-Host "Füge Benutzer $username zu Gruppe $($user.Department)-Group hinzu"
    Add-ADGroupMember -Identity "$($user.Department)-Group" -Members $username

    # Benutzerberechtigungen auslesen und zu den entsprechenden Gruppen hinzufügen
    $userPermission = $userPermissions | Where-Object { $_.Name -eq $user.Name }
    if ($userPermission -ne $null) {
        foreach ($permissionGroup in $userPermission.Permissions) {
            Write-Host "Füge Benutzer $username zu Gruppe $permissionGroup hinzu"
            Add-ADGroupMember -Identity $permissionGroup -Members $username
        }
    } else {
        Write-Host "Keine spezifischen Berechtigungen für Benutzer $username gefunden."
    }
}