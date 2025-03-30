# Hier werden OUs mit dem Entsprechenden pfad erstellt (-Path)

New-ADOrganizationalUnit -Name "Technotrans" -Path "DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name "Gefue-Abt" -Path "OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name "Vertrieb-Abt" -Path "OU=Technotrans,DC=Technotrans,DC=dom"
New-ADOrganizationalUnit -Name "Versand-Abt" -Path "OU=Technotrans,DC=Technotrans,DC=dom"


#Users der Domaene hinzufuegen 

New-ADUser -Name "Olaf Oben" -SamAccountName "Olaf.Oben" -UserPrincipalName "Olaf.Oben@Technotrans.dom" -Path "OU=Geschaeftsfuehrer,OU=Technotrans,DC=Technotrans,DC=dom" -AccountPassword (ConvertTo-SecureString "Password1" -AsPlainText -Force) -PasswordNeverExpires $true -Enabled $true
New-ADUser -Name "Max Mitte" -SamAccountName "Max.Mitte" -UserPrincipalName "Max.Mitte@Technotrans.dom" -Path "OU=Vertrieb-Abt,OU=Technotrans,DC=Technotrans,DC=dom" -AccountPassword (ConvertTo-SecureString "Password1" -AsPlainText -Force) -PasswordNeverExpires $true -Enabled $true
New-ADUser -Name "Ute Unten" -SamAccountName "Ute.Unten" -UserPrincipalName "Ute.Unten@Technotrans.dom" -Path "OU=Versand-Abt,OU=Technotrans,DC=Technotrans,DC=dom" -AccountPassword (ConvertTo-SecureString "Password1" -AsPlainText -Force) -PasswordNeverExpires $true -Enabled $true



# Erstellen der Verzeichnisse wenn ein Fileserver erstellt werden soll, muss dieser Abschnitt auf dem FS ausgefuehrt werden, nicht auf dem DC
New-Item -Path "E:\Firmendaten\Gefue-Daten" -ItemType Directory
New-Item -Path "E:\Firmendaten\Vertrieb-Daten" -ItemType Directory
New-Item -Path "E:\Firmendaten\Versand-Daten" -ItemType Directory

# Setzen von NTFS-Berechtigungen modify = Lesen und schreiben / Read = Lesen
$acl = Get-Acl "E:\Firmendaten\Gefue-Daten"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Olaf Oben", "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "E:\Firmendaten\Gefue-Daten" $acl

$acl = Get-Acl "E:\Firmendaten\Vertrieb-Daten"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Max Mitte", "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "E:\Firmendaten\Vertrieb-Daten" $acl

$acl = Get-Acl "E:\Firmendaten\Versand-Daten"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Ute Unten", "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "E:\Firmendaten\Versand-Daten" $acl

# Ordner Netzwerkfreigabe setzen (muss auf dem server ausgefuehrt werden wo der Ordner erstellt wurde. Moeglich der Fileserver falls vorhanden)
# Erstellen der Netzwerkfreigaben mit Berechtigungen
New-SmbShare -Name "Gefue-Daten" -Path "E:\Firmendaten\Gefue-Daten" -FullAccess "Olaf Oben"
New-SmbShare -Name "Vertrieb-Daten" -Path "E:\Firmendaten\Vertrieb-Daten" -FullAccess "Max Mitte"
New-SmbShare -Name "Versand-Daten" -Path "E:\Firmendaten\Versand-Daten" -ReadAccess "Ute Unten"


# Beispiel fuer die Erstellung einer VPN-Verbindung 
Add-VpnConnection -Name "VPN PPTP" -ServerAddress "vpn.technotrans.com" -TunnelType "Pptp" -AuthenticationMethod "EAP" -SplitTunneling $true
Add-VpnConnection -Name "VPN L2TP" -ServerAddress "vpn.technotrans.com" -TunnelType "L2tp" -L2tpPsk "PreSharedKey" -AuthenticationMethod "EAP" -SplitTunneling $true
Add-VpnConnection -Name "VPN SSTP" -ServerAddress "vpn.technotrans.com" -TunnelType "Sstp" -AuthenticationMethod "EAP" -SplitTunneling $true