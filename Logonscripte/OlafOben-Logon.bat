:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\OlafOben-Logon.bat
@echo off
:: Logon Script für Olaf Oben (Geschaeftsfuehrung)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home /persistent:yes

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Gefue-Daten /persistent:yes

echo Netzlaufwerke für Olaf Oben wurden erfolgreich eingebunden.