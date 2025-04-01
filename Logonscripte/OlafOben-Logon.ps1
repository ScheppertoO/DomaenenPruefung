# Logon Script für Olaf Oben (Geschaeftsfuehrung)

# Home-Verzeichnis einbinden
New-PSDrive -Name "H" -PSProvider FileSystem -Root "\\Server\Home" -Persist

# Abteilungs-Verzeichnis einbinden
New-PSDrive -Name "X" -PSProvider FileSystem -Root "\\Server\Firmendaten\Gefue-Daten" -Persist

Write-Host "Netzlaufwerke für Olaf Oben wurden erfolgreich eingebunden."
