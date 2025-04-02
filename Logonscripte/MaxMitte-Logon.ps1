# Logon Script für Max Mitte (Vertrieb)

# Home-Verzeichnis einbinden
New-PSDrive -Name "H" -PSProvider FileSystem -Root "\\Server\Home"  

# Abteilungs-Verzeichnis einbinden
New-PSDrive -Name "X" -PSProvider FileSystem -Root "\\Server\Firmendaten\Vertrieb-Daten"  

Write-Host "Netzlaufwerke für Max Mitte wurden erfolgreich eingebunden."
