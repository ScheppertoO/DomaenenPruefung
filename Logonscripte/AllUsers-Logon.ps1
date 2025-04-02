# Universelles Logon-Script für alle Benutzer

# Benutzerinformationen ermitteln
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$username = $currentUser.Split('\')[1]

# Home-Verzeichnis einbinden für alle Benutzer
New-PSDrive -Name "H" -PSProvider FileSystem -Root "\\Server\Home"  

# Bestimme Abteilungsverzeichnis basierend auf Benutzername
$departmentPath = "\\Server\Firmendaten"

if ($username -eq "OlafOben") {
    $departmentPath += "\Gefue-Daten"
}
elseif ($username -eq "MaxMitte") {
    $departmentPath += "\Vertrieb-Daten"
}
elseif ($username -eq "UteUnten") {
    $departmentPath += "\Versand-Daten"
}

# Abteilungs-Verzeichnis einbinden
New-PSDrive -Name "X" -PSProvider FileSystem -Root $departmentPath  

Write-Host "Netzlaufwerke für $username wurden erfolgreich eingebunden."
