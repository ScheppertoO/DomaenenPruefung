# Domain-Setup Skripte - Anleitung

## Übersicht der neuen, variablen Skripte

### 1. `Simple-Domain-Setup.ps1` - **EMPFOHLEN FÜR EINSTEIGER**
Das einfachste Skript für schnelle Domain-Konfiguration.

**Verwendung:**
1. Skript öffnen
2. Konfiguration oben im Skript anpassen:
   ```powershell
   # 1. FIRMA UND DOMAIN
   $CompanyName = "IhreFirma"
   $DomainName = "DC=ihre,DC=domain"
   $DomainSuffix = "@ihre.domain"
   $DefaultPassword = "IhrPasswort123"
   
   # 2. BENUTZER HINZUFÜGEN/ÄNDERN
   $UserList = @(
       "Max Mustermann|Max|Mustermann|IT|max.mustermann|Modify",
       "Anna Schmidt|Anna|Schmidt|Buchhaltung|anna.schmidt|Read"
   )
   ```
3. Skript ausführen

**Features:**
- ✅ Einfache Konfiguration über Textliste
- ✅ Automatische OU-Erstellung
- ✅ Benutzer-Erstellung
- ✅ Ordner und Berechtigungen
- ✅ Netzwerkfreigaben
- ✅ Optional: VPN-Verbindungen

### 2. `Domain.ps1` - **VERBESSERTE VERSION**
Das überarbeitete Original-Skript mit Konfiguration am Anfang.

**Verwendung:**
1. Konfigurationsblock am Anfang anpassen:
   ```powershell
   # Domain-Konfiguration
   $DomainConfig = @{
       CompanyName = "Technotrans"
       DomainDN = "DC=demo,DC=dom"
       DomainSuffix = "@demo.dom"
       DefaultPassword = "Password1"
   }
   
   # Benutzer-Konfiguration
   $UsersConfig = @(
       @{
           Name = "Max Muster"
           SamAccountName = "max.muster"
           Department = "IT"
           OUName = "IT-Abt"
           FolderName = "IT-Daten"
           FolderPermission = "Modify"
       }
   )
   ```

### 3. `AddUsersWithOUstrukture_Enhanced.ps1` - **ERWEITERT**
Das komplexeste Skript mit ADGLP-Prinzip und erweiterten Sicherheitsgruppen.

**Features:**
- ✅ ADGLP-Prinzip (A-Accounts, G-Global Groups, DL-Domain Local Groups, P-Permissions)
- ✅ Automatische Gruppenerstellung
- ✅ Erweiterte OU-Struktur
- ✅ Gruppen-Nesting
- ✅ Detaillierte Berechtigungen

### 4. `Config-Template.ps1` - **VORLAGEN**
Enthält Konfigurationsvorlagen für verschiedene Szenarien.

## Schnellstart

### Für Einsteiger:
1. `Simple-Domain-Setup.ps1` verwenden
2. Nur die ersten 20 Zeilen anpassen
3. Ausführen

### Für erweiterte Anforderungen:
1. `AddUsersWithOUstrukture_Enhanced.ps1` verwenden
2. Konfiguration am Anfang anpassen
3. Erweiterte Gruppenstrukturen werden automatisch erstellt

## Beispiel-Konfigurationen

### Einfache Firma mit 3 Abteilungen:
```powershell
$UserList = @(
    "Chef Manager|Chef|Manager|Geschaeftsfuehrung|chef.manager|Modify",
    "IT Admin|IT|Admin|IT|it.admin|Modify",
    "Verkauf Mitarbeiter|Verkauf|Mitarbeiter|Vertrieb|verkauf.mitarbeiter|Read"
)
```

### Große Firma mit vielen Abteilungen:
```powershell
$UsersConfig = @(
    @{Name="Anna Admin"; Department="IT"; OUName="IT-Abt"; Username="anna.admin"},
    @{Name="Bob Buchhalter"; Department="Finanzen"; OUName="Finanzen-Abt"; Username="bob.buchhalter"},
    @{Name="Clara Chef"; Department="Geschaeftsfuehrung"; OUName="GL-Abt"; Username="clara.chef"},
    @{Name="David Developer"; Department="Entwicklung"; OUName="Dev-Abt"; Username="david.developer"}
)
```

## Vorteile der neuen Skripte

### ✅ Variabel und wiederverwendbar
- Nur Konfiguration am Anfang ändern
- Gleiche Skripte für verschiedene Firmen verwendbar
- Einfach neue Benutzer hinzufügen

### ✅ Fehlerbehandlung
- Prüfung auf bereits existierende OUs/Benutzer
- Detaillierte Fehlerausgaben
- Überspringen bei Fehlern statt Abbruch

### ✅ Benutzerfreundlich
- Farbige Ausgaben
- Fortschrittsanzeigen
- Zusammenfassung am Ende

### ✅ Flexibel
- Optional: Ordner erstellen
- Optional: Freigaben erstellen
- Optional: VPN-Verbindungen
- Optional: Erweiterte Gruppenstrukturen

## Migration von alten Skripten

### Von `Domain.ps1` (alt):
1. `Simple-Domain-Setup.ps1` verwenden
2. Ihre Benutzerdaten in die `$UserList` eintragen
3. Domain-Einstellungen anpassen

### Von `AddUsersWithOUstrukture.ps1` (alt):
1. `AddUsersWithOUstrukture_Enhanced.ps1` verwenden
2. Konfiguration am Anfang anpassen
3. Erweiterte Funktionen sind bereits integriert

## Tipps

### Passwort-Sicherheit:
```powershell
# Für Produktion sicheres Passwort verwenden:
$DefaultPassword = "$(Get-Random -Min 1000 -Max 9999)Password!"
```

### Verschiedene Umgebungen:
```powershell
# Test-Umgebung
$CompanyName = "Test-Firma"
$DomainName = "DC=test,DC=local"

# Produktions-Umgebung  
$CompanyName = "Produktions-Firma"
$DomainName = "DC=prod,DC=com"
```

### Backup vor Ausführung:
```powershell
# Domain-Zustand vor Änderungen sichern
Get-ADUser -Filter * | Export-Csv "backup-users.csv"
Get-ADOrganizationalUnit -Filter * | Export-Csv "backup-ous.csv"
```

## Support

Bei Problemen:
1. Prüfen Sie die Fehlermeldungen (rot markiert)
2. Stellen Sie sicher, dass Active Directory PowerShell-Modul installiert ist
3. Führen Sie PowerShell als Administrator aus
4. Prüfen Sie Domain-Controller Erreichbarkeit

## Lizenz

Diese Skripte sind für Bildungszwecke und interne Verwendung gedacht.
