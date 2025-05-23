# Benutzerabfrage fuer den Servernamen
$serverName = Read-Host "Bitte geben Sie den Servernamen des Fileservers ein"

# Benutzerinformationen
$users = @(
    @{Name="UteUnten"; DepartmentPath="Firmendaten"},
    @{Name="MaxMitte"; DepartmentPath="Firmendaten"},
    @{Name="OlafOben"; DepartmentPath="Firmendaten"}
)

# Pfad fuer die Logonskripte
$logonScriptPath ="C:\test"<#"C:\Windows\SYSVOL\sysvol\technotrans.dom\scripts "#>

# Logonskripte generieren
foreach ($user in $users) {
    $batFileName = "$logonScriptPath\$($user.Name -replace ' ', '')-Logon.bat"
    $batContent = @"
@echo off
:: Logon Script fuer $($user.Name)

:: Home-Verzeichnis einbinden
net use H: \\$serverName\Home\$($user.Name)

:: Abteilungs-Verzeichnis einbinden
net use X: \\$serverName\$($user.DepartmentPath)
"@
    # Speichern der .bat-Datei
    $batContent | Set-Content -Path $batFileName -Encoding UTF8
    Write-Host "Logonskript erstellt: $batFileName"
}