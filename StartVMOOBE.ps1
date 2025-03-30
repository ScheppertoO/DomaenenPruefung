# XML-Inhalt generieren muss nach der New-PSSession passieren.
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


<# Define VM name and credentials
$vmName = "FirstVM"
$username = "Administrator"
$password = "Password1"

# Start the VM
Start-VM -Name $vmName

# Wait for the VM to boot up (adjust the sleep time as necessary)
Start-Sleep -Seconds 300

# Establish a PowerShell session with the VM
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
$session = New-PSSession -VMName $vmName -Credential $credential

# Configure the Administrator account
Invoke-Command -Session $session -ScriptBlock {
    # Set the full name of the Administrator account
    $adminUser = Get-WmiObject -Class Win32_UserAccount -Filter "Name='Administrator'"
    $adminUser.FullName = "Administrator"
    $adminUser.Put()

    # Set the password never expires option
    $adminUser.PasswordExpires = $false
    $adminUser.Put()
}

# Close the session
Remove-PSSession -Session $session
#>

# VMs, die konfiguriert werden sollen
$vmNames = @("FirstVM", "SecondVM", "ThirdVM") # Fügen Sie hier die Namen aller VMs ein
$username = "Administrator"
$password = "Password1"

# Loop VMs
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

    # Admin Account 
    Write-Host "Configuring VM $vmName..."
    Invoke-Command -Session $session -ScriptBlock {
        # Set the full name of the Administrator account
        $adminUser = Get-WmiObject -Class Win32_UserAccount -Filter "Name='Administrator'"
        $adminUser.FullName = "Administrator"
        $adminUser.Put()

        # "Password1" läuft nie aus 
        $adminUser.PasswordExpires = $false
        $adminUser.Put()
    }

    # Close the session
    Remove-PSSession -Session $session
    Write-Host "Finished processing VM: $vmName"
    
    
    $response = Read-Host "Möchten Sie einen zusätzlichen Schritt für VM $vmName ausführen? (Ja/Nein)"
    if ($response -eq "Ja") {
        Write-Host "Zusätzlicher Schritt wird für VM $vmName ausgeführt..."
        Write-Host "Shutting down VM: $vmName..."
        Stop-VM -Name $vmName -Force
        Write-Host "VM $vmName ."
        Invoke-Command -VMName $vmName -ScriptBlock {
            New-Item -Path "C:\Temp" -ItemType Directory -Force
        }
        Write-Host "Zusätzlicher Schritt abgeschlossen."
    } else {
        Write-Host "Zusätzlicher Schritt wird übersprungen."
    }
    
}

Write-Host "Fertig du Fisch."