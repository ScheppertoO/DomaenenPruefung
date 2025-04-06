# 🛠️ Verbesserungsuebersicht aller Skripte im AD-Projekt

Stand: 06.04.2025  
Diese uebersicht enthaelt Verbesserungsvorschlaege und Besonderheiten zu allen bisher analysierten PowerShell-Skripten des Projekts (Domaene, Benutzer, Gruppen, Fileserver).

---

## 📁 `FileServerPart2.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Zugriffsregel unvollstaendig | Zeile endet bei `$domainPrefix\DL-Gefue-Daten-AE` – vermutlich fehlen weitere Gruppen | `DL-Shared-AE` ergaenzen |
| Mehrfache Werte in AccessRule | `"ReadAndExecute", "Allow"` in einem Array statt einzelnem String | `New-Object FileSystemAccessRule(..., 'ReadAndExecute', 'Allow')` einzeln je Regel verwenden |
| Keine Freigabe vorhanden | Nur NTFS-Rechte definiert, keine SMB-Freigabe | `New-SmbShare` ergaenzen |
| Access-Based Enumeration fehlt | Wird laut Anforderung erwartet | `Set-SmbShare -FolderEnumerationMode AccessBased` ergaenzen |

###  Beispiel: Firmendaten-Freigabe

```powershell
New-SmbShare -Name "Firmendaten$" -Path "E:\Firmendaten" -FullAccess "TECHNOTRANS\DL-Firmendaten-L"
Set-SmbShare -Name "Firmendaten$" -FolderEnumerationMode AccessBased
```

---

## 🧱 `Domain.ps1` & `DomaeneAufsetzen.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| NetBIOS vs. FQDN | FQDN `technotrans.dom` ist korrekt, aber Anmeldung erfolgt mit `TECHNOTRANS\Administrator` | Kommentar im Skript einfuegen, z. B.: „Anmeldung mit TECHNOTRANS\Administrator“ |
| Kein Logging vorhanden | Bei Fehlern keine Nachvollziehbarkeit | `Out-File`, `Start-Transcript` oder Logging ergaenzen |
| Rolleninstallation kommentarlos | Installation von Features erfolgt ohne Erklaerung | Abschnittsweise kommentieren (ADDS, DNS, Heraufstufung etc.) |

---

## 👥 `AddUsersWithOUstrukture.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Naming Convention unklar | Gruppen wie `DL-Shared-AE`, `DL-Gefue-Daten-AE` ohne Schema-Doku | Kommentar oder README mit Namensschema anlegen |
| Benutzerpasswoerter im Klartext | Sicherheitsrisiko | uebergabe ueber `Read-Host -AsSecureString` oder Passwortdatei verschluesselt |
| Keine Pruefung auf Vorhandensein | OUs und Gruppen werden ohne Check erzeugt | Vorher pruefen mit `Get-ADOrganizationalUnit` / `Get-ADGroup` |

###  Beispiel: Passwortuebergabe sicher

```powershell
$SecurePass = Read-Host "Passwort eingeben" -AsSecureString
New-ADUser -Name "Max Mustermann" -AccountPassword $SecurePass -Enabled $true
```

---

## 🗃️ `FileServerPart1.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Kein Hinweis zur Domaenenanmeldung | FQDN `technotrans.dom` vs. Anmeldung `TECHNOTRANS\Administrator` | Klarer Kommentar ergaenzen |
| Kein Test auf vorhandene Ordner | `New-Item` wird ohne Pruefung ausgefuehrt | `Test-Path` vor `New-Item` verwenden |
| Rechtevergabe teilweise redundant | Zugriff fuer gleiche Gruppen mehrfach gesetzt | Berechtigungen konsolidieren, ggf. ueber Hashtable strukturieren |

---

##  PowerShell Direct (generell)

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Abhaengigkeit von Hyper-V | PS Direct funktioniert nur lokal in Hyper-V | Dokumentieren in README oder Doku („nur mit lokalem Hyper-V moeglich“) |
| Keine Fehlerbehandlung | `Invoke-Command` ohne `-ErrorAction` | Ergaenzen mit `-ErrorAction Stop` + `try/catch` |

```powershell
try {
    Invoke-Command -VMName "DC01" -ScriptBlock { Install-WindowsFeature AD-Domain-Services } -ErrorAction Stop
} catch {
    Write-Error "Installation fehlgeschlagen: $_"
}
```

---

##  Empfehlung

- Alle Skripte mit Header-Block kommentieren: Zweck, Voraussetzungen, Zielsystem(e)
- Einheitliche Strukturierung (z. B. Funktionen fuer wiederverwendbare Teile)
- Logging oder Protokollierung ergaenzen
- Optionale Validierungsskripte: Pruefen, ob alles wie gewuenscht eingerichtet ist

---

Wenn du willst, kann ich das auch in eine `.xlsx` oder `.pdf` umwandeln – einfach melden!