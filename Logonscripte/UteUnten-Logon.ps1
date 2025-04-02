# Logon Script für Ute Unten (Versand)

# Home-Verzeichnis einbinden
New-PSDrive -Name "H" -PSProvider FileSystem -Root "\\Server\Home"  

# Abteilungs-Verzeichnis einbinden
New-PSDrive -Name "X" -PSProvider FileSystem -Root "\\Server\Firmendaten\Versand-Daten"  

Write-Host "Netzlaufwerke für Ute Unten wurden erfolgreich eingebunden."
