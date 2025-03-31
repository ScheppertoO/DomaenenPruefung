# 💻 Anleitung: Änderungen speichern und mergen mit GitHub

## 🛠️ Schritte im Detail

### 1️⃣ Änderungen lokal committen

Speichere deine Änderungen in deinem aktuellen Branch:

```bash
git add .
git commit -m "Beschreibung der Änderungen"
```

---

### 2️⃣ Zum Haupt-Branch (`main`) wechseln

Wechsle zunächst zum Haupt-Branch:

```bash
git checkout main
```

---

### 3️⃣ Haupt-Branch aktualisieren

Hole die neuesten Änderungen vom Remote-Repository (`origin`) auf deinen lokalen `main`-Branch:

```bash
git pull origin main
```

---

### 4️⃣ Änderungen mergen

Führe die Änderungen deines Feature-Branches in den Haupt-Branch ein:

```bash
git merge <feature-branch-name>
```

---

### 5️⃣ Konflikte lösen (falls nötig)

Falls es Merge-Konflikte gibt, bearbeite die betroffenen Dateien und markiere sie als gelöst:

```bash
git add <datei-name>
git commit -m "Konflikte gelöst"
```

---

### 6️⃣ Änderungen in das Remote-Repository hochladen

Lade die Änderungen vom Haupt-Branch ins Remote-Repository hoch:

```bash
git push origin main
```

---

## 📋 Übersicht nützlicher Befehle

| **Befehl**                    | **Beschreibung**                                 |
|-------------------------------|--------------------------------------------------|
| `git branch`                  | Zeigt alle lokalen Branches an                   |
| `git checkout <branch-name>`  | Wechselt zu einem bestimmten Branch              |
| `git add .`                   | Fügt alle Änderungen zum Commit hinzu            |
| `git commit -m "Nachricht"`   | Speichert die Änderungen lokal                   |
| `git pull origin <branch>`    | Aktualisiert den aktuellen Branch vom Remote     |
| `git push origin <branch>`    | Schiebt die Änderungen ins Remote-Repository     |
