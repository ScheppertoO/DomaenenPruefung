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
Invoke-Command -Session $session -ScriptBlock {
    Write-Host "Überprüfe Netzwerkadapter & IP-Konfiguration..."

    $interfaceAlias = "Ethernet 2"
    $targetIP = "192.168.200.101"
    $prefix = 24
    $dnsServer = "127.0.0.1"
    #$defaultGateway = "192.168.200.1"  # optional

    # Prüfen, ob der Adapter existiert
    $adapter = Get-NetAdapter -Name $interfaceAlias -ErrorAction SilentlyContinue
    if (-not $adapter) {
        Write-Host "❌ Adapter '$interfaceAlias' wurde nicht gefunden." -ForegroundColor Red
        return
    }

    # Prüfen, ob IP bereits korrekt gesetzt ist
    $ipExists = Get-NetIPAddress -InterfaceAlias $interfaceAlias -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -eq $targetIP -and $_.PrefixLength -eq $prefix }

    if ($ipExists) {
        Write-Host "✅ IP-Adresse $targetIP ist bereits gesetzt – keine Änderung nötig."
    } else {
        Write-Host "⚙️ Setze IP-Adresse auf $targetIP..."
        # Alte IPs ggf. entfernen (optional)
        Get-NetIPAddress -InterfaceAlias $interfaceAlias -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        # Neue IP setzen
        New-NetIPAddress `
            -InterfaceAlias $interfaceAlias `
            -IPAddress $targetIP `
            -PrefixLength $prefix `
            -DefaultGateway $defaultGateway `
            -AddressFamily IPv4

        # DNS setzen
        Set-DnsClientServerAddress `
            -InterfaceAlias $interfaceAlias `
            -ServerAddresses $dnsServer

        Write-Host "✅ Statische IP & DNS wurden gesetzt."
    }
}


    Invoke-Command -Session $session -ScriptBlock {
        Write-Host "Installiere AD-Domain-Services Rolle..."
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Write-Host "Rolle AD-Domain-Services installiert."
            Start-Sleep -Seconds 60 # Warten auf die Installation der Rolle um sicher zu stellen es ist Fertig Installiert 
        Write-Host "Heraufstufen zum Domain Controller in der DomÃ¤ne technotrans.dom..."
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