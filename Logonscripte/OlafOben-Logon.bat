:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\OlafOben-Logon.bat
@echo off
:: Logon Script für Olaf Oben (Gefue)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home 

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Gefue-Daten