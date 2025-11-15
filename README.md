# Docker Server - Feuerwehrverein Raura

Automatisches Provisionierungssystem für `docker.fwv-raura.ch` mit Traefik, n8n, Nextcloud und (später) Mailcow.

## Übersicht

Dieses Repository enthält die komplette Docker-Infrastruktur für den Server `docker.fwv-raura.ch`. Die Konfiguration wird automatisch via GitHub Actions bei jedem Push auf den `main` Branch deployed.

### Enthaltene Services

- **Traefik** - Reverse Proxy mit automatischen SSL-Zertifikaten (Let's Encrypt via Cloudflare DNS)
- **n8n** - Workflow-Automatisierung
- **Nextcloud** - Cloud-Speicher mit MariaDB und Redis
- **Mailcow** - E-Mail Server (Vorbereitet für spätere Installation)

### Architektur

```
/opt/docker/
├── docker-compose.yml          # Haupt-Compose-Datei mit allen Services
├── .env                        # Umgebungsvariablen (NICHT im Git!)
├── traefik/                    # Traefik Konfiguration
│   ├── traefik.yml
│   ├── config.yml
│   └── acme.json              # SSL-Zertifikate (NICHT im Git!)
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

SSH zum Server verbinden und das Setup-Script ausführen:

```bash
# Auf dem Server
cd /root
git clone https://github.com/Feuerwehrverein-Raura/docker.fwv-raura.ch.git
cd docker.fwv-raura.ch
chmod +x setup-server.sh
./setup-server.sh
```

Das Script installiert:
- Docker & Docker Compose
- UFW Firewall (konfiguriert für HTTP/HTTPS/SSH)
- Fail2Ban
- Erstellt `/opt/docker` Verzeichnis

### 2. Umgebungsvariablen konfigurieren

```bash
cd /opt/docker
cp .env.example .env
nano .env
```

Wichtige Werte anpassen:

```bash
# Cloudflare API für SSL Zertifikate
CF_API_EMAIL=admin@fwv-raura.ch
CF_DNS_API_TOKEN=dein_cloudflare_token_hier

# Traefik Dashboard Passwort (generieren mit: htpasswd -nb admin dein_passwort)
TRAEFIK_BASIC_AUTH=admin:$apr1$xxxxxxxx$yyyyyyyyyyyyyyyy

# Nextcloud Datenbank Passwörter
NEXTCLOUD_DB_ROOT_PASSWORD=sicheres_root_passwort
NEXTCLOUD_DB_PASSWORD=sicheres_db_passwort

# Nextcloud Admin
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=sicheres_admin_passwort
```

### 3. Cloudflare API Token erstellen

1. Gehe zu https://dash.cloudflare.com/profile/api-tokens
2. Klicke "Create Token"
3. Verwende Template "Edit zone DNS"
4. Zone Resources: Include → Specific zone → `fwv-raura.ch`
5. Kopiere den Token in `.env`

### 4. Traefik Basic Auth Passwort generieren

Online: https://hostingcanada.org/htpasswd-generator/

Oder lokal:
```bash
htpasswd -nb admin dein_passwort
```

**WICHTIG:** In der `.env` Datei müssen `$` Zeichen verdoppelt werden: `$$`

### 5. DNS Einträge setzen

Stelle sicher, dass folgende DNS A-Records auf die Server-IP zeigen:

```
traefik.fwv-raura.ch  →  <server-ip>
n8n.fwv-raura.ch      →  <server-ip>
cloud.fwv-raura.ch    →  <server-ip>
```

Optional (für später):
```
mail.fwv-raura.ch     →  <server-ip>
```

### 6. Erstes manuelles Deployment

Vom lokalen Rechner:

```bash
chmod +x deploy.sh
./deploy.sh
```

Oder direkt auf dem Server:

```bash
cd /opt/docker
docker-compose up -d
```

## GitHub Actions Setup

Für automatisches Deployment bei Git Push müssen folgende Secrets in GitHub hinterlegt werden:

### GitHub Secrets einrichten

1. Gehe zu: Repository → Settings → Secrets and variables → Actions
2. Füge folgende Secrets hinzu:

| Secret Name | Wert | Beschreibung |
|------------|------|--------------|
| `SSH_PRIVATE_KEY` | `<ssh-private-key>` | SSH Private Key für Server-Zugriff |
| `SERVER_HOST` | `docker.fwv-raura.ch` | Server Hostname |
| `SERVER_USER` | `root` | SSH Benutzer |
| `SERVER_PORT` | `22` | SSH Port |
| `DEPLOY_PATH` | `/opt/docker` | Deployment Pfad auf dem Server |

### SSH Key einrichten

Wenn noch kein SSH Key existiert:

```bash
# Auf lokalem Rechner
ssh-keygen -t ed25519 -C "github-actions@fwv-raura.ch"

# Public Key auf Server hinterlegen
ssh-copy-id root@docker.fwv-raura.ch

# Private Key als GitHub Secret hinterlegen
cat ~/.ssh/id_ed25519  # Inhalt kopieren und als SSH_PRIVATE_KEY Secret einfügen
```

### Automatisches Deployment

Ab jetzt wird bei jedem Push auf `main` automatisch deployed:

```bash
git add .
git commit -m "Update Konfiguration"
git push origin main
```

GitHub Actions führt aus:
1. Dateien zum Server syncen
2. Docker Images pullen
3. Container neu starten
4. Status überprüfen

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

## Zugriff auf Services

Nach erfolgreichem Deployment sind die Services erreichbar unter:

- **Traefik Dashboard**: https://traefik.fwv-raura.ch
  - Login mit Basic Auth (siehe `.env`)

- **n8n**: https://n8n.fwv-raura.ch
  - Beim ersten Besuch Admin-Account erstellen

- **Nextcloud**: https://cloud.fwv-raura.ch
  - Login mit Admin-Credentials aus `.env`

## Wartung

### Updates durchführen

```bash
cd /opt/docker
docker-compose pull      # Neue Images herunterladen
docker-compose up -d     # Container mit neuen Images starten
docker image prune -f    # Alte Images aufräumen
```

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

#### Komplettes Backup

```bash
# Alle Daten sichern
tar -czf docker-backup-$(date +%Y%m%d).tar.gz \
  /opt/docker/nextcloud/data \
  /opt/docker/nextcloud/db \
  /opt/docker/n8n/data \
  /opt/docker/.env
```

### SSL Zertifikate

Traefik erneuert die Let's Encrypt Zertifikate automatisch. Die Zertifikate werden in `/opt/docker/traefik/acme.json` gespeichert.

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

1. Überprüfe Cloudflare API Token in `.env`
2. Prüfe DNS Records
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

## Mailcow Installation

Für die spätere Installation von Mailcow siehe [MAILCOW.md](MAILCOW.md).

## Sicherheit

### Firewall

UFW ist konfiguriert und erlaubt nur:
- Port 22 (SSH)
- Port 80 (HTTP)
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

### Updates

Regelmäßige System-Updates:

```bash
apt update
apt upgrade -y
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
├── docker-compose.yml              # Docker Services
├── .env.example                    # Beispiel Umgebungsvariablen
├── .gitignore                      # Git Ignore Regeln
├── deploy.sh                       # Manuelles Deployment Script
├── setup-server.sh                 # Server Ersteinrichtung
├── MAILCOW.md                      # Mailcow Installations-Guide
└── README.md                       # Diese Datei
```

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

## Support & Kontakt

Bei Fragen oder Problemen:

- GitHub Issues: https://github.com/Feuerwehrverein-Raura/docker.fwv-raura.ch/issues
- E-Mail: admin@fwv-raura.ch

## Lizenz

Proprietär - Feuerwehrverein Raura
