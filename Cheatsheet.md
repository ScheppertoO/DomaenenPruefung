# Anleitung: aenderungen speichern und mergen mit GitHub

## Schritte im Detail

### Neuen Branch aus dem Origin Main, sync remote(branchname) to main Origin

Aktualisiere vom Origin

```bash
git fetch origin
```

Erstelle Remote aus Main Origin

```bash
git checkout -b feature-branch origin/main
```

Falls du sicherstellen möchtest, dass der Tracking-Branch richtig gesetzt ist, kannst du folgenden Befehl nutzen:

```bash
git branch --set-upstream-to=origin/main feature-branch
```

 1. aenderungen lokal committen

Speichere deine aenderungen in deinem aktuellen Branch:

```bash
git add .
git commit -m "Beschreibung der aenderungen"
```

### 2. Zum Haupt-Branch (`main`) wechseln

Wechsle zunaechst zum Haupt-Branch:

```bash
git checkout main
```

### 3. Haupt-Branch aktualisieren

Hole die neuesten aenderungen vom Remote-Repository (`origin`) auf deinen lokalen `main`-Branch:

```bash
git pull origin main
```

### 4. aenderungen mergen

Fuehre die aenderungen deines Feature-Branches in den Haupt-Branch ein:

```bash
git merge <feature-branch-name>
```

### 5. Konflikte loesen (falls noetig)

Falls es Merge-Konflikte gibt, bearbeite die betroffenen Dateien und markiere sie als geloest:

```bash
git add <datei-name>
git commit -m "Konflikte geloest"
```

### 6. aenderungen in das Remote-Repository hochladen

Lade die aenderungen vom Haupt-Branch ins Remote-Repository hoch:

```bash
git push origin main
```

---

## uebersicht nuetzlicher Befehle

| **Befehl**                    | **Beschreibung**                                 |
|-------------------------------|--------------------------------------------------|
| `git branch`                  | Zeigt alle lokalen Branches an                   |
| `git checkout <branch-name>`  | Wechselt zu einem bestimmten Branch              |
| `git add .`                   | Fuegt alle aenderungen zum Commit hinzu            |
| `git commit -m "Nachricht"`   | Speichert die aenderungen lokal                   |
| `git pull origin <branch>`    | Aktualisiert den aktuellen Branch vom Remote     |
| `git push origin <branch>`    | Schiebt die aenderungen ins Remote-Repository     |