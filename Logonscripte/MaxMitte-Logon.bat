:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\MaxMitte-Logon.bat
@echo off
:: Logon Script fuer Max Mitte (Vertrieb)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home /persistent:yes

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Vertrieb-Daten /persistent:yes

echo Netzlaufwerke fuer Max Mitte wurden erfolgreich eingebunden.