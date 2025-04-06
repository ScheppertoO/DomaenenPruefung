# 🛠️ Verbesserungsübersicht aller Skripte im AD-Projekt

Stand: 06.04.2025  
Diese Übersicht enthält Verbesserungsvorschläge und Besonderheiten zu allen bisher analysierten PowerShell-Skripten des Projekts (Domäne, Benutzer, Gruppen, Fileserver).

---

## 📁 `FileServerPart2.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Zugriffsregel unvollständig | Zeile endet bei `$domainPrefix\DL-Gefue-Daten-AE` – vermutlich fehlen weitere Gruppen | `DL-Shared-AE` ergänzen |
| Mehrfache Werte in AccessRule | `"ReadAndExecute", "Allow"` in einem Array statt einzelnem String | `New-Object FileSystemAccessRule(..., 'ReadAndExecute', 'Allow')` einzeln je Regel verwenden |
| Keine Freigabe vorhanden | Nur NTFS-Rechte definiert, keine SMB-Freigabe | `New-SmbShare` ergänzen |
| Access-Based Enumeration fehlt | Wird laut Anforderung erwartet | `Set-SmbShare -FolderEnumerationMode AccessBased` ergänzen |

### ✅ Beispiel: Firmendaten-Freigabe

```powershell
New-SmbShare -Name "Firmendaten$" -Path "E:\Firmendaten" -FullAccess "TECHNOTRANS\DL-Firmendaten-L"
Set-SmbShare -Name "Firmendaten$" -FolderEnumerationMode AccessBased
```

---

## 🧱 `Domain.ps1` & `DomaeneAufsetzen.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| NetBIOS vs. FQDN | FQDN `technotrans.dom` ist korrekt, aber Anmeldung erfolgt mit `TECHNOTRANS\Administrator` | Kommentar im Skript einfügen, z. B.: „Anmeldung mit TECHNOTRANS\Administrator“ |
| Kein Logging vorhanden | Bei Fehlern keine Nachvollziehbarkeit | `Out-File`, `Start-Transcript` oder Logging ergänzen |
| Rolleninstallation kommentarlos | Installation von Features erfolgt ohne Erklärung | Abschnittsweise kommentieren (ADDS, DNS, Heraufstufung etc.) |

---

## 👥 `AddUsersWithOUstrukture.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Naming Convention unklar | Gruppen wie `DL-Shared-AE`, `DL-Gefue-Daten-AE` ohne Schema-Doku | Kommentar oder README mit Namensschema anlegen |
| Benutzerpasswörter im Klartext | Sicherheitsrisiko | Übergabe über `Read-Host -AsSecureString` oder Passwortdatei verschlüsselt |
| Keine Prüfung auf Vorhandensein | OUs und Gruppen werden ohne Check erzeugt | Vorher prüfen mit `Get-ADOrganizationalUnit` / `Get-ADGroup` |

### ✅ Beispiel: Passwortübergabe sicher

```powershell
$SecurePass = Read-Host "Passwort eingeben" -AsSecureString
New-ADUser -Name "Max Mustermann" -AccountPassword $SecurePass -Enabled $true
```

---

## 🗃️ `FileServerPart1.ps1`

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Kein Hinweis zur Domänenanmeldung | FQDN `technotrans.dom` vs. Anmeldung `TECHNOTRANS\Administrator` | Klarer Kommentar ergänzen |
| Kein Test auf vorhandene Ordner | `New-Item` wird ohne Prüfung ausgeführt | `Test-Path` vor `New-Item` verwenden |
| Rechtevergabe teilweise redundant | Zugriff für gleiche Gruppen mehrfach gesetzt | Berechtigungen konsolidieren, ggf. über Hashtable strukturieren |

---

## ⚙️ PowerShell Direct (generell)

| Thema | Problem | Vorschlag |
|-------|---------|-----------|
| Abhängigkeit von Hyper-V | PS Direct funktioniert nur lokal in Hyper-V | Dokumentieren in README oder Doku („nur mit lokalem Hyper-V möglich“) |
| Keine Fehlerbehandlung | `Invoke-Command` ohne `-ErrorAction` | Ergänzen mit `-ErrorAction Stop` + `try/catch` |

```powershell
try {
    Invoke-Command -VMName "DC01" -ScriptBlock { Install-WindowsFeature AD-Domain-Services } -ErrorAction Stop
} catch {
    Write-Error "Installation fehlgeschlagen: $_"
}
```

---

## ✅ Empfehlung

- Alle Skripte mit Header-Block kommentieren: Zweck, Voraussetzungen, Zielsystem(e)
- Einheitliche Strukturierung (z. B. Funktionen für wiederverwendbare Teile)
- Logging oder Protokollierung ergänzen
- Optionale Validierungsskripte: Prüfen, ob alles wie gewünscht eingerichtet ist

---

Wenn du willst, kann ich das auch in eine `.xlsx` oder `.pdf` umwandeln – einfach melden!