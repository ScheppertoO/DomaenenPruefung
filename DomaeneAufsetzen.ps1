<# Konfiguration der Zugangsdaten
$adminUser = "Administrator"
$adminPass = "Password1"
$secPass = ConvertTo-SecureString $adminPass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($adminUser, $secPass)
#>
$vmNames = "DC" #@("FirstVM", "SecondVM", "ThirdVM") # Fuegen Sie hier die Namen aller VMs ein
$username = "Administrator"
$password = "Password1"

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

    Write-Host "Heraufstufen zum Domain Controller in der Domäne technotrans.dom..."
    $securePass = ConvertTo-SecureString "Password1" -AsPlainText -Force
    $adminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $securePass)
    
    Install-ADDSForest `
        -DomainName "technotrans.dom" `
        -DomainNetbiosName "TECHNOTRANS" `
        -SafeModeAdministratorPassword $adminCred.Password `
        -Force `
        -NoRebootOnCompletion
}

# Optional: Nach der Heraufstufung Neustart (deaktiviert, falls nicht gewünscht)
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
    while (-not $sessionReady) {
        try {
            $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
            $session = New-PSSession -VMName $vmName -Credential $credential
            $sessionReady = $true
        } catch {
            Write-Host "VM $vmName is not ready yet. Retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        }
    }

    Invoke-Command -Session $session -ScriptBlock {
        Write-Host "Installiere AD-Domain-Services Rolle..."
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Write-Host "Rolle AD-Domain-Services installiert."
            Start-Sleep -Seconds 60 # Warten auf die Installation der Rolle um sicher zu stellen es ist Fertig Installiert 
        Write-Host "Heraufstufen zum Domain Controller in der Domäne technotrans.dom..."
        $securePass = ConvertTo-SecureString "Password1" -AsPlainText -Force
        $adminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $securePass)
        
        Install-ADDSForest `
            -DomainName "technotrans.dom" `
            -DomainNetbiosName "TECHNOTRANS" `
            -SafeModeAdministratorPassword $adminCred.Password `
            -Force `
            -NoRebootOnCompletion
    }
Start-Sleep -Seconds 60 # Warten auf die Installation der Rolle um sicher zu stellen es ist Fertig Installiert
    # Close the session
    Remove-PSSession -Session $session
    Write-Host "Finished processing VM: $vmName"
}
Write-Host "Domain"