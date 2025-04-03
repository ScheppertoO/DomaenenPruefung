:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\OlafOben-Logon.bat
@echo off
:: Logon Script fuer Olaf Oben (Geschaeftsfuehrung)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home /persistent:yes

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Gefue-Daten /persistent:yes

echo Netzlaufwerke fuer Olaf Oben wurden erfolgreich eingebunden.