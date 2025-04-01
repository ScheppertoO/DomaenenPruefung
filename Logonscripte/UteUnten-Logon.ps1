# Logon Script für Ute Unten (Versand)

# Home-Verzeichnis einbinden
New-PSDrive -Name "H" -PSProvider FileSystem -Root "\\Server\Home" -Persist

# Abteilungs-Verzeichnis einbinden
New-PSDrive -Name "X" -PSProvider FileSystem -Root "\\Server\Firmendaten\Versand-Daten" -Persist

Write-Host "Netzlaufwerke für Ute Unten wurden erfolgreich eingebunden."
