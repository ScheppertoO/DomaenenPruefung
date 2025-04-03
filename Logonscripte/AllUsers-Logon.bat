:: filepath: c:\Users\kesch\Documents\GitHub\DomaenenPruefung\AllUsers-Logon.bat
@echo off
:: Universelles Logon-Script für alle Benutzer

:: Home-Verzeichnis einbinden für alle Benutzer
net use H: \\Server\Home /persistent:yes

:: Bestimme Abteilungsverzeichnis basierend auf Benutzername
set departmentPath=\\Server\Firmendaten

if "%USERNAME%"=="OlafOben" (
    set departmentPath=\\Server\Firmendaten\Gefue-Daten
) else if "%USERNAME%"=="MaxMitte" (
    set departmentPath=\\Server\Firmendaten\Vertrieb-Daten
) else if "%USERNAME%"=="UteUnten" (
    set departmentPath=\\Server\Firmendaten\Versand-Daten
)

:: Abteilungs-Verzeichnis einbinden
net use X: %departmentPath% /persistent:yes

echo Netzlaufwerke für %USERNAME% wurden erfolgreich eingebunden.