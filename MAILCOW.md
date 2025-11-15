# Mailcow Installation Guide

Diese Anleitung erklärt, wie Mailcow später zum bestehenden Setup hinzugefügt werden kann.

## Voraussetzungen

- Traefik läuft bereits und verwaltet SSL-Zertifikate
- Domain `mail.fwv-raura.ch` zeigt auf den Server
- Port 25, 587, 465, 110, 995, 143, 993 müssen in der Firewall geöffnet werden

## Installation

### 1. Firewall Ports öffnen

```bash
# Auf dem Server ausführen
ufw allow 25/tcp comment 'SMTP'
ufw allow 587/tcp comment 'SMTP Submission'
ufw allow 465/tcp comment 'SMTPS'
ufw allow 110/tcp comment 'POP3'
ufw allow 995/tcp comment 'POP3S'
ufw allow 143/tcp comment 'IMAP'
ufw allow 993/tcp comment 'IMAPS'
ufw allow 4190/tcp comment 'Sieve'
```

### 2. Mailcow herunterladen

```bash
cd /opt/docker
git clone https://github.com/mailcow/mailcow-dockerized mailcow
cd mailcow
```

### 3. Konfiguration generieren

```bash
./generate_config.sh
```

Wenn gefragt, folgende Werte eingeben:
- Hostname: `mail.fwv-raura.ch`
- Timezone: `Europe/Zurich`

### 4. Mailcow konfigurieren

Bearbeite `mailcow.conf`:

```bash
nano mailcow.conf
```

Wichtige Einstellungen:
```conf
MAILCOW_HOSTNAME=mail.fwv-raura.ch
MAILCOW_TZ=Europe/Zurich

# Deaktiviere Mailcow's eigenen Webserver (da wir Traefik verwenden)
HTTP_PORT=8080
HTTPS_PORT=8443

# Optinal: Verwende vorhandene Traefik Zertifikate
SKIP_LETS_ENCRYPT=y
```

### 5. Integration mit Traefik

Erstelle `docker-compose.override.yml` im mailcow Verzeichnis:

```yaml
version: '2.1'

services:
  nginx-mailcow:
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mailcow.entrypoints=http"
      - "traefik.http.routers.mailcow.rule=Host(`mail.fwv-raura.ch`)"
      - "traefik.http.middlewares.mailcow-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.mailcow.middlewares=mailcow-https-redirect"
      - "traefik.http.routers.mailcow-secure.entrypoints=https"
      - "traefik.http.routers.mailcow-secure.rule=Host(`mail.fwv-raura.ch`)"
      - "traefik.http.routers.mailcow-secure.tls=true"
      - "traefik.http.routers.mailcow-secure.tls.certresolver=cloudflare"
      - "traefik.http.routers.mailcow-secure.service=mailcow"
      - "traefik.http.services.mailcow.loadbalancer.server.port=8080"
      - "traefik.docker.network=proxy"

networks:
  proxy:
    external: true
```

### 6. Mailcow starten

```bash
docker-compose pull
docker-compose up -d
```

### 7. Zugriff

- Webinterface: `https://mail.fwv-raura.ch`
- Standard Login: `admin` / `moohoo`
- **WICHTIG:** Ändere das Passwort sofort nach dem ersten Login!

## DNS Konfiguration

Für Mailcow müssen folgende DNS Records gesetzt werden:

### MX Record
```
@ IN MX 10 mail.fwv-raura.ch.
```

### A Record
```
mail IN A <server-ip>
```

### SPF Record
```
@ IN TXT "v=spf1 mx ~all"
```

### DKIM Record
Nach dem Start von Mailcow generiert das System einen DKIM Key.
Diesen findest du im Webinterface unter: **Configuration > Configuration & Details > Configuration > ARC/DKIM keys**

### DMARC Record
```
_dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:postmaster@fwv-raura.ch"
```

### Reverse DNS (PTR)
Stelle sicher, dass der Reverse DNS (PTR) Record deiner Server-IP auf `mail.fwv-raura.ch` zeigt.
Dies muss meist beim Hosting-Provider konfiguriert werden.

## Wartung

### Backup erstellen
```bash
cd /opt/docker/mailcow
./helper-scripts/backup_and_restore.sh backup all
```

### Updates
```bash
cd /opt/docker/mailcow
./update.sh
```

### Logs anzeigen
```bash
cd /opt/docker/mailcow
docker-compose logs -f
```

## Troubleshooting

### Ports überprüfen
```bash
netstat -tulpn | grep -E ':(25|587|465|993|995|143|110|4190)'
```

### Container Status
```bash
cd /opt/docker/mailcow
docker-compose ps
```

### SSL Zertifikate
Falls Probleme mit SSL auftreten, prüfe ob Traefik die Zertifikate korrekt generiert hat:
```bash
cat /opt/docker/traefik/acme.json
```

## Wichtige Hinweise

- Mailcow benötigt mindestens **6 GB RAM** für stabilen Betrieb
- Die Installation kann 10-15 Minuten dauern beim ersten Start
- Regelmäßige Backups sind essentiell!
- Überwache die Logs auf Fehler in den ersten 24 Stunden

## Weitere Informationen

Offizielle Mailcow Dokumentation: https://docs.mailcow.email/
