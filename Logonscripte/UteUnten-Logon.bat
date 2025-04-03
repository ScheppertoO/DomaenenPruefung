:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\UteUnten-Logon.bat
@echo off
:: Logon Script für Ute Unten (Versand)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home /persistent:yes

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Versand-Daten /persistent:yes

echo Netzlaufwerke für Ute Unten wurden erfolgreich eingebunden.