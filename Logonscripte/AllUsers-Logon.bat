@echo off
net use H: \\Server\Home 


set departmentPath=\\Server\Firmendaten

if "%USERNAME%"=="OlafOben" (
    set departmentPath=\\Server\Firmendaten\Gefue-Daten
) else if "%USERNAME%"=="MaxMitte" (
    set departmentPath=\\Server\Firmendaten\Vertrieb-Daten
) else if "%USERNAME%"=="UteUnten" (
    set departmentPath=\\Server\Firmendaten\Versand-Daten
)

net use X: %departmentPath% 