# Docker Server - Feuerwehrverein Raura

Automatisches Provisionierungssystem für `docker.fwv-raura.ch` mit Traefik, Portainer, Authentik, n8n, Nextcloud und (später) Mailcow.

⚠️ **WICHTIG**: Dieses Repository ist PUBLIC. Alle sensiblen Daten (Passwörter, API Keys) werden als GitHub Secrets verwaltet und NIEMALS ins Repository committed!

## Übersicht

Dieses Repository enthält die komplette Docker-Infrastruktur für den Server `docker.fwv-raura.ch`. Die Konfiguration wird automatisch via GitHub Actions bei jedem Push auf den `main` Branch deployed.

### Enthaltene Services

**Produktions-Services:**
- **Traefik** - Reverse Proxy mit automatischen SSL-Zertifikaten (Let's Encrypt via HTTP Challenge)
- **Portainer** - Docker Management Web-UI
- **Authentik** - Identity Provider für Single Sign-On (SSO)
- **n8n** - Workflow-Automatisierung
- **Nextcloud** - Cloud-Speicher mit MariaDB und Redis
- **Mailcow** - E-Mail Server (Vorbereitet für spätere Installation)

**Security & Monitoring:**
- **CrowdSec** - IDS/IPS mit Community Threat Intelligence
- **Traefik Bouncer** - Web Application Firewall Integration
- **Watchtower** - Automatische Container-Updates mit E-Mail-Benachrichtigungen
- **Unattended-Upgrades** - Automatische Debian-Sicherheitsupdates mit E-Mail-Benachrichtigungen
- **Fail2Ban** - SSH Brute-Force Protection
- **UFW** - Firewall
- **rkhunter** - Rootkit Detection
- **Lynis** - Security Auditing

### Architektur

```
/opt/docker/
├── docker-compose.yml          # Haupt-Compose-Datei mit allen Services
├── .env                        # Umgebungsvariablen (NICHT im Git! Wird von GitHub Actions erstellt)
├── traefik/                    # Traefik Konfiguration
│   ├── traefik.yml
│   ├── config.yml
│   └── acme.json              # SSL-Zertifikate (NICHT im Git!)
├── portainer/                 # Portainer Daten
│   └── data/
├── authentik/                 # Authentik Daten
│   ├── postgresql/
│   ├── redis/
│   ├── media/
│   ├── certs/
│   └── custom-templates/
├── n8n/                       # n8n Daten
│   └── data/
├── nextcloud/                 # Nextcloud Daten
│   ├── db/                   # MariaDB Datenbank
│   ├── html/                 # Nextcloud Installation
│   ├── data/                 # Benutzer-Daten
│   ├── config/               # Konfiguration
│   └── apps/                 # Custom Apps
└── mailcow/                  # Mailcow (später)
```

## Erste Einrichtung

### 1. Server Vorbereitung

🎉 **AUTOMATISCH!** GitHub Actions richtet den Server beim ersten Deployment automatisch ein!

Der Workflow prüft ob Docker installiert ist und führt bei Bedarf automatisch aus:
- Docker & Docker Compose Installation
- UFW Firewall (konfiguriert für HTTP/HTTPS/SSH)
- Fail2Ban
- Erstellt `/opt/docker` Verzeichnis
- Erstellt Docker Netzwerke (proxy, nextcloud, authentik)

**Du musst NICHTS manuell auf dem Server machen!** Einfach GitHub Secrets setzen und auf `main` pushen → Fertig! 🚀

<details>
<summary>💡 Alternative: Manuelles Server-Setup (falls gewünscht)</summary>

Falls du den Server trotzdem manuell einrichten möchtest:

**Option A: Via git clone**
```bash
# Auf dem Server (einmalig!)
cd /tmp
git clone https://github.com/Feuerwehrverein-Raura/docker.fwv-raura.ch.git
cd docker.fwv-raura.ch
chmod +x setup-server.sh
sudo ./setup-server.sh

# Aufräumen
cd /tmp && rm -rf docker.fwv-raura.ch
```

**Option B: setup-server.sh direkt hochladen**
```bash
# Lokal
scp setup-server.sh root@docker.fwv-raura.ch:/tmp/

# Auf dem Server
ssh root@docker.fwv-raura.ch
chmod +x /tmp/setup-server.sh
sudo /tmp/setup-server.sh
```

</details>

### 2. DNS Einträge setzen

Stelle sicher, dass folgende DNS A-Records auf die Server-IP zeigen:

```
traefik.fwv-raura.ch    →  <server-ip>
portainer.fwv-raura.ch  →  <server-ip>
auth.fwv-raura.ch       →  <server-ip>
n8n.fwv-raura.ch        →  <server-ip>
cloud.fwv-raura.ch      →  <server-ip>
```

Optional (für später):
```
mail.fwv-raura.ch       →  <server-ip>
```

**WICHTIG**: Die Domains müssen erreichbar sein, bevor du die Container startest, da Traefik die Let's Encrypt Zertifikate via HTTP Challenge erstellt!

### 3. GitHub Secrets konfigurieren

Da das Repository PUBLIC ist, werden alle sensiblen Daten als GitHub Secrets gespeichert.

#### Benötigte GitHub Secrets

Gehe zu: Repository → Settings → Secrets and variables → Actions → New repository secret

##### Server Zugang

| Secret Name | Beispiel-Wert | Beschreibung |
|------------|---------------|--------------|
| `SSH_PRIVATE_KEY` | `-----BEGIN...` | SSH Private Key für Server-Zugriff |
| `SERVER_HOST` | `docker.fwv-raura.ch` | Server Hostname |
| `SERVER_USER` | `root` | SSH Benutzer |
| `SERVER_PORT` | `22` | SSH Port |
| `DEPLOY_PATH` | `/opt/docker` | Deployment Pfad auf dem Server |

##### Traefik

| Secret Name | Beispiel-Wert | Generierung |
|------------|---------------|-------------|
| `TRAEFIK_BASIC_AUTH` | `admin:$apr1$...` | `htpasswd -nb admin dein_passwort` oder [Online Generator](https://hostingcanada.org/htpasswd-generator/) |

⚠️ **WICHTIG**: Bei htpasswd müssen `$` Zeichen NICHT verdoppelt werden (im Gegensatz zur .env Datei)!

##### Nextcloud

| Secret Name | Beispiel-Wert | Generierung |
|------------|---------------|-------------|
| `NEXTCLOUD_DB_ROOT_PASSWORD` | `8a3f9c2d...` | `openssl rand -hex 16` |
| `NEXTCLOUD_DB_PASSWORD` | `7b2e8f1a...` | `openssl rand -hex 16` |
| `NEXTCLOUD_ADMIN_USER` | `admin` | Dein gewünschter Admin Username |
| `NEXTCLOUD_ADMIN_PASSWORD` | `dein-sicheres-passwort` | Sicheres Passwort |

##### Authentik

| Secret Name | Beispiel-Wert | Generierung |
|------------|---------------|-------------|
| `AUTHENTIK_SECRET_KEY` | `6d4a9c2f...` (64 Zeichen) | `openssl rand -hex 32` |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | `5e3b7a9d...` | `openssl rand -hex 16` |

##### CrowdSec

| Secret Name | Beispiel-Wert | Generierung |
|------------|---------------|-------------|
| `CROWDSEC_BOUNCER_KEY_TRAEFIK` | `4f7c2b9a...` | `openssl rand -hex 32` |

⚠️ **Hinweis**: Der CrowdSec Bouncer Key sollte ein zufälliger String sein. Bei der ersten Installation wird CrowdSec diesen Key automatisch registrieren.

##### SMTP/Email-Konfiguration

Diese Secrets werden von mehreren Services verwendet:
- **Watchtower**: Container-Update-Benachrichtigungen
- **Postfix**: System-Update-Benachrichtigungen (unattended-upgrades)
- **Authentik**: Passwort-Resets, Account-Verifizierung, Benachrichtigungen
- **Zukünftige Services**: Nextcloud, n8n können diese auch nutzen

| Secret Name | Beispiel-Wert | Beschreibung |
|------------|---------------|--------------|
| `EMAIL_FROM` | `notifications@fwv-raura.ch` | Absender-E-Mail für alle Benachrichtigungen |
| `EMAIL_TO` | `admin@fwv-raura.ch` | Empfänger-E-Mail für alle Benachrichtigungen |
| `SMTP_SERVER` | `mail.fwv-raura.ch` | SMTP Server für E-Mail-Versand |
| `SMTP_PORT` | `587` | SMTP Port (normalerweise 587 für TLS) |
| `SMTP_USER` | `notifications@fwv-raura.ch` | SMTP Benutzername |
| `SMTP_PASSWORD` | `dein-smtp-passwort` | SMTP Passwort |

⚠️ **Wichtig bei den Secrets**:
- Alle Secret-Werte sollten **OHNE zusätzliche Leerzeichen oder Zeilenumbrüche** gespeichert werden
- Kopiere Secret-Werte direkt, ohne versehentlich Enter zu drücken
- Der GitHub Actions Workflow trimmt automatisch Whitespace, aber saubere Werte sind besser

#### SSH Key einrichten

Wenn noch kein SSH Key für GitHub Actions existiert:

```bash
# Auf lokalem Rechner
ssh-keygen -t ed25519 -C "github-actions@fwv-raura.ch" -f ~/.ssh/github_actions

# Public Key auf Server hinterlegen
ssh-copy-id -i ~/.ssh/github_actions.pub root@docker.fwv-raura.ch

# Private Key als GitHub Secret hinterlegen
cat ~/.ssh/github_actions  # Inhalt kopieren und als SSH_PRIVATE_KEY Secret einfügen
```

### 4. Manuelles Erstes Deployment (Optional)

Falls du das System manuell deployen möchtest (ohne GitHub Actions):

```bash
# Lokal
chmod +x deploy.sh

# .env Datei manuell auf Server erstellen
ssh root@docker.fwv-raura.ch
cd /opt/docker
cp .env.example .env
nano .env  # Werte anpassen

# Deployment ausführen
./deploy.sh
```

## Automatisches Deployment via GitHub Actions

### Workflow

Bei jedem Push auf `main` Branch:

1. ✓ Code wird ausgecheckt
2. ✓ SSH Verbindung zum Server wird aufgebaut
3. ✓ **Server-Setup wird geprüft** (falls Docker nicht installiert → automatisches Setup!)
4. ✓ Deployment-Struktur wird erstellt
5. ✓ Dateien werden via rsync zum Server übertragen
6. ✓ `.env` Datei wird aus GitHub Secrets erstellt
7. ✓ `acme.json` Berechtigungen werden gesetzt
8. ✓ Docker Netzwerke werden erstellt
9. ✓ Docker Images werden gepullt
10. ✓ Container werden neu gestartet
11. ✓ Health Check wird durchgeführt

**Beim allerersten Deployment** auf einem frischen Server:
- GitHub Actions erkennt, dass Docker fehlt
- Lädt `setup-server.sh` hoch und führt es aus
- Installiert Docker, Firewall, Fail2Ban
- Fährt dann mit normalem Deployment fort

**Kein manueller Server-Zugriff nötig!** 🎉

### Deployment triggern

```bash
git add .
git commit -m "Update Konfiguration"
git push origin main
```

GitHub Actions startet automatisch und deployed alle Änderungen zum Server.

### Clean Deployment (Container neu aufsetzen)

Manchmal ist es nötig, alle Container komplett zu entfernen und neu zu deployen, z.B. bei Problemen oder zum Aufräumen. Die Clean Deployment Option entfernt alle Container, behält aber alle Daten (Datenbanken, Konfigurationen, etc.)!

**Option 1: Manuelle Auslösung via GitHub Actions UI**
1. Gehe zu: Repository → Actions → "Deploy to Server"
2. Klicke auf "Run workflow"
3. Wähle den `main` Branch
4. Aktiviere die Checkbox "Force clean deployment (stop and remove all containers, keep data)"
5. Klicke auf "Run workflow"

**Option 2: Automatisch via Commit Message**

Füge einen dieser Tags in deine Commit Message ein:
```bash
git commit -m "Fix Container-Konfiguration [clean-deploy]"
git push origin main
```

Oder:
```bash
git commit -m "Rebuild all services [force-redeploy]"
git push origin main
```

**Was passiert beim Clean Deployment:**
- 🛑 Alle Container werden gestoppt
- 🗑️ Alle Container werden entfernt (`docker-compose down --remove-orphans`)
- 💾 **ALLE DATEN BLEIBEN ERHALTEN** (Volumes werden NICHT gelöscht)
- 🧹 Docker System Prune wird ausgeführt (entfernt ungenutzte Images/Networks)
- 🚀 Normales Deployment läuft weiter und baut alle Container neu auf

**Wann nützlich:**
- Container starten nicht mehr korrekt
- Nach größeren Konfigurationsänderungen
- Verdacht auf beschädigte Container
- Zum Aufräumen alter Container-Images

⚠️ **WICHTIG**: Deine Datenbanken, Nextcloud-Dateien, Authentik-Konfigurationen, etc. bleiben alle erhalten! Es werden nur die Container neu gebaut.

## Zugriff auf Services

Nach erfolgreichem Deployment sind die Services erreichbar unter:

- **Traefik Dashboard**: https://traefik.fwv-raura.ch
  - Login mit Basic Auth (aus GitHub Secret `TRAEFIK_BASIC_AUTH`)
  - Zeigt alle Routen, Middlewares und SSL-Zertifikate

- **Portainer**: https://portainer.fwv-raura.ch
  - Beim ersten Besuch Admin-Account erstellen
  - Docker Container Management UI

- **Authentik**: https://auth.fwv-raura.ch
  - Standard-Login: `akadmin` (ohne Passwort bei Erstinstallation)
  - Bei Ersteinrichtung: Verwende die "Password Recovery" Funktion auf der Login-Seite, um ein Passwort für `akadmin` zu setzen
  - Identity Provider für SSO
  - Nach Installation: Admin-Passwort ändern und Nutzer anlegen!

- **n8n**: https://n8n.fwv-raura.ch
  - Beim ersten Besuch Admin-Account erstellen
  - Workflow-Automatisierung

- **Nextcloud**: https://cloud.fwv-raura.ch
  - Login mit Admin-Credentials aus GitHub Secrets
  - Cloud-Speicher und Collaboration

## Verwendung

### Services starten

```bash
cd /opt/docker
docker-compose up -d
```

### Services stoppen

```bash
cd /opt/docker
docker-compose down
```

### Logs anzeigen

```bash
# Alle Services
cd /opt/docker
docker-compose logs -f

# Einzelner Service
docker-compose logs -f traefik
docker-compose logs -f portainer
docker-compose logs -f authentik-server
docker-compose logs -f n8n
docker-compose logs -f nextcloud
```

### Container Status

```bash
cd /opt/docker
docker-compose ps
```

### Services neu starten

```bash
cd /opt/docker
docker-compose restart
```

### Einzelnen Service neu starten

```bash
cd /opt/docker
docker-compose restart traefik
```

## Authentik Integration (SSO)

Authentik kann als zentrale Authentifizierung für alle Services verwendet werden:

### Nextcloud mit Authentik verbinden

1. In Authentik: Erstelle einen OAuth2/OpenID Provider
2. In Nextcloud: Installiere die "OpenID Connect" App
3. Konfiguriere die App mit den Authentik Credentials

### n8n mit Authentik verbinden

1. In Authentik: Erstelle einen OAuth2 Provider
2. In n8n: Konfiguriere External OAuth unter Settings
3. Nutzer können sich mit Authentik anmelden

### Traefik Forward Auth mit Authentik

Authentik kann als Forward Auth Middleware für Traefik verwendet werden, um alle Services zu schützen:

```yaml
# In traefik/config.yml
http:
  middlewares:
    authentik:
      forwardAuth:
        address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
```

## Wartung

### Updates durchführen

```bash
cd /opt/docker
docker-compose pull      # Neue Images herunterladen
docker-compose up -d     # Container mit neuen Images starten
docker image prune -f    # Alte Images aufräumen
```

Oder automatisch via GitHub Actions: Einfach auf `main` Branch pushen!

### Backups

#### Nextcloud Backup

```bash
# Datenbank Backup
docker exec nextcloud-db mysqldump -u root -p'<ROOT_PASSWORD>' nextcloud > nextcloud-db-backup.sql

# Dateien Backup
tar -czf nextcloud-backup.tar.gz /opt/docker/nextcloud/data
```

#### n8n Backup

```bash
tar -czf n8n-backup.tar.gz /opt/docker/n8n/data
```

#### Authentik Backup

```bash
# PostgreSQL Backup
docker exec authentik-postgresql pg_dump -U authentik authentik > authentik-db-backup.sql

# Dateien Backup
tar -czf authentik-backup.tar.gz /opt/docker/authentik/media
```

#### Komplettes Backup

```bash
# Alle Daten sichern
tar -czf docker-backup-$(date +%Y%m%d).tar.gz \
  /opt/docker/nextcloud/data \
  /opt/docker/nextcloud/db \
  /opt/docker/n8n/data \
  /opt/docker/authentik/postgresql \
  /opt/docker/authentik/media \
  /opt/docker/portainer/data
```

### SSL Zertifikate

Traefik erneuert die Let's Encrypt Zertifikate automatisch via **HTTP Challenge**.

**Wichtig**: Port 80 muss von außen erreichbar sein, damit Let's Encrypt die Domain validieren kann!

Die Zertifikate werden in `/opt/docker/traefik/acme.json` gespeichert.

Zertifikate manuell überprüfen:

```bash
cat /opt/docker/traefik/acme.json | jq
```

### Disk Space überprüfen

```bash
# Gesamter Speicher
df -h

# Docker Speicherverbrauch
docker system df

# Alte Container/Images aufräumen
docker system prune -a
```

## Troubleshooting

### Container startet nicht

```bash
# Logs überprüfen
docker-compose logs <service-name>

# Container Status
docker-compose ps
```

### SSL Zertifikate werden nicht generiert

1. Prüfe dass Port 80 von außen erreichbar ist
2. Prüfe DNS Records (müssen auf Server zeigen)
3. Prüfe Traefik Logs: `docker-compose logs traefik`
4. Falls nötig, acme.json löschen und neu starten:
   ```bash
   rm /opt/docker/traefik/acme.json
   touch /opt/docker/traefik/acme.json
   chmod 600 /opt/docker/traefik/acme.json
   docker-compose restart traefik
   ```

### Nextcloud zeigt Fehler

```bash
# In Nextcloud Container einloggen
docker exec -it nextcloud bash

# Wartungsmodus aktivieren
su -s /bin/bash www-data -c 'php occ maintenance:mode --on'

# Cache leeren
su -s /bin/bash www-data -c 'php occ maintenance:repair'

# Wartungsmodus deaktivieren
su -s /bin/bash www-data -c 'php occ maintenance:mode --off'
```

### Port bereits belegt

```bash
# Prüfe welcher Prozess Port 80/443 verwendet
netstat -tulpn | grep :80
netstat -tulpn | grep :443

# Stoppe konfliktierenden Service (z.B. Apache)
systemctl stop apache2
systemctl disable apache2
```

### GitHub Actions Deployment schlägt fehl

1. Überprüfe dass alle GitHub Secrets korrekt hinterlegt sind
2. Prüfe SSH Key Berechtigung
3. Checke GitHub Actions Logs im Repository
4. Teste SSH Verbindung manuell:
   ```bash
   ssh -i ~/.ssh/github_actions root@docker.fwv-raura.ch
   ```

## Mailcow Installation

Für die spätere Installation von Mailcow siehe [MAILCOW.md](MAILCOW.md).

## Sicherheit

### GitHub Secrets

⚠️ **WICHTIG**: Dieses Repository ist PUBLIC!

- Alle Passwörter und sensiblen Daten sind als GitHub Secrets gespeichert
- Die `.env` Datei wird NIE ins Repository committed
- Die `.env` Datei wird bei jedem Deployment von GitHub Actions neu erstellt
- Secrets sind nur für Repository-Admins sichtbar

### Firewall

UFW ist konfiguriert und erlaubt nur:
- Port 22 (SSH)
- Port 80 (HTTP - für Let's Encrypt Challenge)
- Port 443 (HTTPS)

Zusätzliche Ports öffnen:

```bash
ufw allow <port>/tcp comment 'Beschreibung'
```

### Fail2Ban

Fail2Ban ist aktiv und schützt vor Brute-Force-Angriffen auf SSH.

Status überprüfen:

```bash
fail2ban-client status
```

### Automatische System Updates

**Automatische Sicherheitsupdates** sind konfiguriert mit `unattended-upgrades`:
- Täglich automatische Installation von Sicherheitsupdates
- E-Mail-Benachrichtigungen bei Fehlern an `admin@fwv-raura.ch`
- Automatisches Cleanup alter Kernel-Pakete

Status prüfen:
```bash
systemctl status unattended-upgrades
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

Manuelle Updates (falls benötigt):
```bash
apt update
apt upgrade -y
```

## GitHub Secrets Übersicht

Vollständige Zusammenfassung aller benötigten GitHub Secrets:

### Alle Secrets

```bash
# ==========================================
# Server Zugang (5 Secrets)
# ==========================================
SSH_PRIVATE_KEY=<private-key-content>
SERVER_HOST=docker.fwv-raura.ch
SERVER_USER=root
SERVER_PORT=22
DEPLOY_PATH=/opt/docker

# ==========================================
# Traefik (1 Secret)
# ==========================================
TRAEFIK_BASIC_AUTH=admin:$apr1$...

# ==========================================
# Nextcloud (4 Secrets)
# ==========================================
NEXTCLOUD_DB_ROOT_PASSWORD=<generated>
NEXTCLOUD_DB_PASSWORD=<generated>
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=<secure-password>

# ==========================================
# Authentik (2 Secrets)
# ==========================================
AUTHENTIK_SECRET_KEY=<generated-64-chars>
AUTHENTIK_POSTGRESQL_PASSWORD=<generated>

# ==========================================
# CrowdSec (1 Secret)
# ==========================================
CROWDSEC_BOUNCER_KEY_TRAEFIK=<generated>

# ==========================================
# SMTP/Email (6 Secrets)
# ==========================================
EMAIL_FROM=notifications@fwv-raura.ch
EMAIL_TO=admin@fwv-raura.ch
SMTP_SERVER=mail.fwv-raura.ch
SMTP_PORT=587
SMTP_USER=notifications@fwv-raura.ch
SMTP_PASSWORD=<smtp-password>
```

**Gesamt: 19 GitHub Secrets**

### Script zum Generieren der Passwörter

```bash
#!/bin/bash
echo "=== Generiere sichere Passwörter ==="
echo ""
echo "# Nextcloud"
echo "NEXTCLOUD_DB_ROOT_PASSWORD=$(openssl rand -hex 16)"
echo "NEXTCLOUD_DB_PASSWORD=$(openssl rand -hex 16)"
echo ""
echo "# Authentik"
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -hex 32)"
echo "AUTHENTIK_POSTGRESQL_PASSWORD=$(openssl rand -hex 16)"
echo ""
echo "# CrowdSec"
echo "CROWDSEC_BOUNCER_KEY_TRAEFIK=$(openssl rand -hex 32)"
echo ""
echo "# Traefik Basic Auth"
echo "# Generiere mit: htpasswd -nb admin dein_passwort"
echo "# Oder online: https://hostingcanada.org/htpasswd-generator/"
```

### Checkliste: Sind alle Secrets gesetzt?

- [ ] **Server Zugang** (5/5):
  - [ ] SSH_PRIVATE_KEY
  - [ ] SERVER_HOST
  - [ ] SERVER_USER
  - [ ] SERVER_PORT
  - [ ] DEPLOY_PATH

- [ ] **Traefik** (1/1):
  - [ ] TRAEFIK_BASIC_AUTH

- [ ] **Nextcloud** (4/4):
  - [ ] NEXTCLOUD_DB_ROOT_PASSWORD
  - [ ] NEXTCLOUD_DB_PASSWORD
  - [ ] NEXTCLOUD_ADMIN_USER
  - [ ] NEXTCLOUD_ADMIN_PASSWORD

- [ ] **Authentik** (2/2):
  - [ ] AUTHENTIK_SECRET_KEY
  - [ ] AUTHENTIK_POSTGRESQL_PASSWORD

- [ ] **CrowdSec** (1/1):
  - [ ] CROWDSEC_BOUNCER_KEY_TRAEFIK

- [ ] **SMTP/Email** (6/6):
  - [ ] EMAIL_FROM
  - [ ] EMAIL_TO
  - [ ] SMTP_SERVER
  - [ ] SMTP_PORT
  - [ ] SMTP_USER
  - [ ] SMTP_PASSWORD

✅ **Alle 19 Secrets gesetzt? → Bereit für Deployment!**

## Nützliche Befehle

```bash
# Container neu starten
docker-compose restart

# Alle Container neu bauen und starten
docker-compose up -d --force-recreate

# Container Ressourcen-Nutzung
docker stats

# In Container einloggen
docker exec -it <container-name> bash

# Container Logs live verfolgen
docker-compose logs -f --tail=100

# Alle gestoppten Container entfernen
docker container prune

# Ungenutzte Images entfernen
docker image prune -a

# Komplette Docker Bereinigung
docker system prune -a --volumes
```

## Struktur-Übersicht

```
docker.fwv-raura.ch/
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions Workflow
├── traefik/
│   ├── traefik.yml                 # Traefik Hauptkonfiguration
│   └── config.yml                  # Middleware & Routing
├── docker-compose.yml              # Docker Services (alle)
├── .env.example                    # Beispiel Umgebungsvariablen
├── .gitignore                      # Git Ignore Regeln
├── deploy.sh                       # Manuelles Deployment Script
├── setup-server.sh                 # Server Ersteinrichtung
├── MAILCOW.md                      # Mailcow Installations-Guide
└── README.md                       # Diese Datei
```

## Support & Kontakt

Bei Fragen oder Problemen:

- GitHub Issues: https://github.com/Feuerwehrverein-Raura/docker.fwv-raura.ch/issues
- E-Mail: admin@fwv-raura.ch

## Lizenz

Proprietär - Feuerwehrverein Raura
