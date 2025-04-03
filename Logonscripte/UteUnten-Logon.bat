:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\UteUnten-Logon.bat
@echo off
:: Logon Script fuer Ute Unten (Versand)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home /persistent:yes

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Versand-Daten /persistent:yes

echo Netzlaufwerke fuer Ute Unten wurden erfolgreich eingebunden.