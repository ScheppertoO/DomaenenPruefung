<# $fsVmName = "FILESERV-VM"  # Name der Fileserver-VM in Hyper-V
$fsUser = "Administrator"
$fsPassword = "Password1"
$securePassword = ConvertTo-SecureString $fsPassword -AsPlainText -Force
$fsCredential = New-Object PSCredential ($fsUser, $securePassword) #>

Write-Host " Starte Netzwerkkonfiguration fuer Fileserver..."

$oldName = Read-Host "Gib den genauen des noch Unkonfigurierten Ethernet Adapters an fuers Business" #"Ethernet" 
$newName = "BUSINESS-NIC"
$ipAddress = "192.168.200.11"
$prefix = 24
$dnsServer = "192.168.200.101"
$domainName = "TECHNOTRANS"
$domainJoinUser = "$domainName\Administrator"
$domainJoinPass = ConvertTo-SecureString "Password1" -AsPlainText -Force
$domainCredential = New-Object PSCredential ($domainJoinUser, $domainJoinPass)

# Adapter umbenennen
Rename-NetAdapter -Name $oldName -NewName $newName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# IP pruefen
$ipExists = Get-NetIPAddress -InterfaceAlias $newName -AddressFamily IPv4 |
Where-Object { $_.IPAddress -eq $ipAddress -and $_.PrefixLength -eq $prefix }

if (-not $ipExists) {
    Write-Host " Setze statische IP $ipAddress auf $newName..."
    Get-NetIPAddress -InterfaceAlias $newName -AddressFamily IPv4 |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress `
        -InterfaceAlias $newName `
        -IPAddress $ipAddress `
        -PrefixLength $prefix `
        -AddressFamily IPv4
}
else {
    Write-Host " IP bereits korrekt gesetzt."
}

# DNS setzen
Set-DnsClientServerAddress `
    -InterfaceAlias $newName `
    -ServerAddresses $dnsServer

Write-Host " DNS auf $newName gesetzt: $dnsServer warte auf Netzwerkidentifizierung 15sek"

start-sleep 15

# Domaenenbeitritt
Write-Host " Trete der Domaene $domainName bei..."
Add-Computer -DomainName $domainName -Credential $domainCredential -Force
#Keine Eingabe = Wartet | Eingabe = Neustart | Abbrechen = Stoppe einfach das skript (STRG + C)
Write-Host " Domaenenbeitritt abgeschlossen. Neustart wird durchgefuehrt..."
Read-Host "Jetzt Neustarten, weiter mit Enter"
Restart-Computer
