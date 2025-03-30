$vmNames = @("FirstVM", "SecondVM", "ThirdVM") # Fuegen Sie hier die Namen aller VMs ein
$username = "Administrator"
$password = "Password1"

$xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>0407:00000407</InputLocale>
            <SystemLocale>de-DE</SystemLocale>
            <UILanguage>de-DE</UILanguage>
            <UserLocale>de-DE</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <AutoLogon>
                <Password>
                    <Value>Password1</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Username>Administrator</Username>
                <Enabled>true</Enabled>
            </AutoLogon>
        </component>
    </settings>
</unattend>
"@

# Speichern der Datei innerhalb der PowerShell-Sitzung
Invoke-Command -Session $session -ScriptBlock {
    param($xmlContent)
    $filePath = "C:\Windows\Panther\Unattend.xml"
    $xmlContent | Set-Content -Path $filePath -Encoding UTF8 -Force
    Write-Host "XML-Datei wurde erfolgreich gespeichert: $filePath"
} -ArgumentList $xmlContent

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

    # Configure Unattend.xml
    Write-Host "Configuring unattend.xml on VM $vmName..."
    Invoke-Command -Session $session -ScriptBlock {
        param($xmlContent)
        $filePath = "C:\Windows\Panther\Unattend.xml"
        $xmlContent | Set-Content -Path $filePath -Encoding UTF8 -Force
        Write-Host "XML-Datei wurde erfolgreich gespeichert: $filePath"
    } -ArgumentList $xmlContent

    # Close the session
    Remove-PSSession -Session $session
    Write-Host "Finished processing VM: $vmName"
}
Write-Host "Alle VMs sind fertig konfiguriert!"