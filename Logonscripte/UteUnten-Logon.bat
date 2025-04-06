@echo off
:: Logon Script fuer Ute Unten (Versand)

:: Home-Verzeichnis einbinden
net use H: \\Server\Home 

:: Abteilungs-Verzeichnis einbinden
net use X: \\Server\Firmendaten\Versand-Daten