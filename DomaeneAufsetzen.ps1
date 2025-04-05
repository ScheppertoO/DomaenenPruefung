#Abmin abfrage & exit falls nicht 
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "⚠️  Dieses Skript muss als Administrator ausgeführt werden!"
    Pause
    exit
}


$vmNames = "DomainController" #@("FirstVM", "SecondVM", "ThirdVM") # Fuegen Sie hier die Namen aller VMs ein
$username = "Administrator"
$password = "Password1"
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object PSCredential ($username, $securePassword)

<# Ziel-VM definieren (VM-Name in Hyper-V)
$targetVM = "DC" 

Write-Host "Starte VM $targetVM..."
Start-VM -Name $targetVM

Write-Host "Warte darauf, dass die VM $targetVM gestartet ist..."
do {
    $vmState = (Get-VM -Name $targetVM).State
    Start-Sleep -Seconds 5
} until ($vmState -eq "Running")
Write-Host "VM $targetVM ist gestartet."

Write-Host "Erstelle PSSession zu $targetVM..."
$session = New-PSSession -ComputerName $targetVM -Credential $cred -Authentication Negotiate

Invoke-Command -Session $session -ScriptBlock {
    Write-Host "Installiere AD-Domain-Services Rolle..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    Write-Host "Heraufstufen zum Domain Controller in der DomÃ¤ne technotrans.dom..."
    $securePass = ConvertTo-SecureString "Password1" -AsPlainText -Force
    $adminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $securePass)
    
    Install-ADDSForest `
        -DomainName "technotrans.dom" `
        -DomainNetbiosName "TECHNOTRANS" `
        -SafeModeAdministratorPassword $adminCred.Password `
        -Force `
        -NoRebootOnCompletion
}

# Optional: Nach der Heraufstufung Neustart (deaktiviert, falls nicht gewÃ¼nscht)
Invoke-Command -Session $session -ScriptBlock {
    Write-Host "Heraufstufung abgeschlossen, starte den Server neu..."
    Restart-Computer -Force
}#

# Session bereinigen
Remove-PSSession $session
#
# Speichern der Datei innerhalb der PowerShell-Sitzung
Invoke-Command -Session $session -ScriptBlock {
    param($xmlContent)
    $filePath = "C:\Windows\Panther\Unattend.xml"
    $xmlContent | Set-Content -Path $filePath -Encoding UTF8 -Force
    Write-Host "XML-Datei wurde erfolgreich gespeichert: $filePath"
} -ArgumentList $xmlContent
#>
######################################################################### PSSession ########################################################
foreach ($vmName in $vmNames) {
    Write-Host "Processing VM: $vmName"

    # Start VM
    Start-VM -Name $vmName

    # Wait for VM to be ready
    Write-Host "Waiting for VM $vmName to start..."
    while ((Get-VM -Name $vmName).State -ne 'Running') {
        Start-Sleep -Seconds 5
    }

    # Open PSsession
    Write-Host "Waiting for VM $vmName to be ready for a PowerShell session..."
    $sessionReady = $false
    $timeout = 300
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $sessionReady -and $stopwatch.Elapsed.TotalSeconds -lt $timeout) {
    try {
        $session = New-PSSession -VMName $vmName -Credential $credential
        $sessionReady = $true
    } catch {
        Start-Sleep -Seconds 5
    }
}
if (-not $sessionReady) {
    Write-Host "Timeout beim Herstellen der PS-Session zu $vmName" -ForegroundColor Red
    continue
}

#####################################################################  IP  ##########################################################
Invoke-Command -Session $session -ScriptBlock {
    Write-Host "🔧 Starte Netzwerkkonfiguration..."
#Umschreiben für Goldsteps Umgebung
    # Zielkonfiguration
    $oldName1 = "Ethernet"
    $oldName2 = "Ethernet 2"
    $newName1 = "DefaultNetwork"
    $newName2 = "BUSINESS-NIC"

    $targetIP = "192.168.200.101"
    $prefix = 24
    $dnsServer = "127.0.0.1"

    # Netzwerkkarten umbenennen
    Rename-NetAdapter -Name $oldName1 -NewName $newName1 -ErrorAction SilentlyContinue
    Rename-NetAdapter -Name $oldName2 -NewName $newName2 -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2 # Warten, damit Umbenennung greift

    # Adapterprüfung
    $adapter = Get-NetAdapter -Name $newName2 -ErrorAction SilentlyContinue
    if (-not $adapter) {
        Write-Host "❌ Adapter '$newName2' nicht gefunden!" -ForegroundColor Red
        return
    }

    # Prüfen, ob IP bereits korrekt gesetzt ist
    $ipExists = Get-NetIPAddress -InterfaceAlias $newName2 -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -eq $targetIP -and $_.PrefixLength -eq $prefix }

    if ($ipExists) {
        Write-Host "✅ IP $targetIP ist bereits korrekt gesetzt."
    } else {
        Write-Host "⚙️ Setze IP-Adresse $targetIP auf $newName2..."

        # Vorherige IPs entfernen (optional)
        Get-NetIPAddress -InterfaceAlias $newName2 -AddressFamily IPv4 |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        # Neue IP setzen
        New-NetIPAddress `
            -InterfaceAlias $newName2 `
            -IPAddress $targetIP `
            -PrefixLength $prefix `
            -AddressFamily IPv4

        Write-Host "✅ IP-Adresse gesetzt."
    }

    # DNS setzen auf BUSINESS-NIC
    Set-DnsClientServerAddress `
        -InterfaceAlias $newName2 `
        -ServerAddresses $dnsServer

    Write-Host "✅ DNS für $newName2 gesetzt auf $dnsServer"

    # DNS auf DefaultNetwork entfernen
    Set-DnsClientServerAddress `
        -InterfaceAlias $newName1 `
        -ResetServerAddresses -ErrorAction SilentlyContinue

    Write-Host "🧹 DNS auf $newName1 entfernt"
}
$weiter = Read-Host "Prüfe die IP einstellungen aller Netzwerkadapter, ggf DC nicht funktionsfertig. Weiter mit "j""
if ($weiter.ToLower() -ne 'j') {
    Write-Host "Abgebrochen."
    exit
}


########################################################################  ADDS FEATURE  ##############################################################
    Invoke-Command -Session $session -ScriptBlock {
        Write-Host "Installiere AD-Domain-Services Rolle..."
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Write-Host "Rolle AD-Domain-Services installiert."
            Start-Sleep -Seconds 60 # Warten auf die Installation der Rolle um sicher zu stellen es ist Fertig Installiert 
        Write-Host "Heraufstufen zum Domain Controller in der DomÃ¤ne technotrans.dom..."
        Read-Host "Letzte Chance für Kontrollen. Weiter mit 'j'"
        $weiter = Read-Host "Gib 'j' ein zum Fortfahren"
if ($weiter -ne 'j') {
    Write-Host "Abgebrochen."
    exit
}

        $securePass = ConvertTo-SecureString "Password1" -AsPlainText -Force
        $adminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $securePass)
        
        Install-ADDSForest `
            -DomainName "technotrans.dom" `
            -DomainNetbiosName "TECHNOTRANS" `
            -SafeModeAdministratorPassword $adminCred.Password `
            -Force `
            -Confirm:$false `
            -NoRebootOnCompletion
    }
Start-Sleep -Seconds 60 # Warten auf die Installation der Rolle um sicher zu stellen es ist Fertig Installiert
    # Close the session
    Remove-PSSession -Session $session
    Write-Host "Finished processing VM: $vmName"
}
Write-Host "Domain"