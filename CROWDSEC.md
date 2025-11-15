# CrowdSec Security Stack

Umfassende Intrusion Detection & Prevention mit CrowdSec und zusätzlichen Security Tools.

## Übersicht

Das System nutzt einen mehrschichtigen Security-Ansatz:

- **CrowdSec** - IDS/IPS mit Community Threat Intelligence
- **Traefik Bouncer** - Web Application Firewall Integration
- **Fail2Ban** - SSH Brute-Force Protection (bewährt, parallel zu CrowdSec)
- **rkhunter** - Rootkit Detection
- **Lynis** - Security Auditing
- **Unattended-Upgrades** - Automatische Sicherheitsupdates
- **UFW Firewall** - iptables/nftables Frontend

## CrowdSec Setup

### Was ist CrowdSec?

CrowdSec ist ein modernes, Open-Source IDS/IPS System, das:
- Logs analysiert und verdächtige Aktivitäten erkennt
- Community Threat Intelligence nutzt (CTI)
- Automatisch Angreifer-IPs blockiert
- Scenarios für verschiedene Angriffstypen verwendet

### Komponenten

**1. CrowdSec Agent** (Container)
- Analysiert Logs von Traefik, System, etc.
- Erkennt Angriffsmuster
- Meldet Bans an die Bouncers

**2. Traefik Bouncer** (Container)
- Blockiert gebannte IPs in Traefik
- Schützt alle Web-Services
- Forward Auth Middleware

**3. Collections** (automatisch installiert)
- `crowdsecurity/traefik` - Traefik-spezifische Szenarien
- `crowdsecurity/http-cve` - Erkennung bekannter Web-CVEs
- `crowdsecurity/whitelist-good-actors` - Bekannte gute IPs (Google, GitHub, etc.)
- `crowdsecurity/iptables` - Firewall Integration
- `crowdsecurity/linux` - Linux System Logs

## GitHub Secrets Setup

Füge zu deinen GitHub Secrets hinzu:

### CrowdSec Bouncer Key

```bash
# Generiere einen sicheren Key
openssl rand -hex 32
```

GitHub Secret erstellen:
- Name: `CROWDSEC_BOUNCER_KEY_TRAEFIK`
- Wert: Der generierte Key (64 Zeichen)

## CrowdSec Verwaltung

### Dashboard anzeigen

```bash
# Auf dem Server
ssh root@docker.fwv-raura.ch
cd /opt/docker

# CrowdSec Metrics anzeigen
docker exec crowdsec cscli metrics

# Aktuell gebannte IPs
docker exec crowdsec cscli decisions list

# Alerts anzeigen
docker exec crowdsec cscli alerts list
```

### Manuell eine IP bannen

```bash
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 4h --reason "Manual ban"
```

### IP entbannen (Whitelist)

```bash
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
```

### Whitelist hinzufügen (permanent)

```bash
# Bearbeite CrowdSec Config
nano /opt/docker/crowdsec/config/parsers/s02-enrich/whitelist.yaml
```

Füge hinzu:

```yaml
name: crowdsecurity/whitelists
description: "Whitelist for trusted IPs"
whitelist:
  reason: "Trusted IP"
  ip:
    - "192.168.1.0/24"    # Dein lokales Netzwerk
    - "1.2.3.4"           # Spezifische IP
  expression:
    - evt.Meta.source_ip == '10.0.0.1'
```

Dann CrowdSec neu starten:

```bash
docker-compose restart crowdsec
```

### Collections verwalten

```bash
# Alle installierten Collections anzeigen
docker exec crowdsec cscli collections list

# Neue Collection installieren
docker exec crowdsec cscli collections install crowdsecurity/sshd

# Collection upgraden
docker exec crowdsec cscli collections upgrade crowdsecurity/traefik
```

### Scenarios verwalten

```bash
# Alle Scenarios anzeigen
docker exec crowdsec cscli scenarios list

# Scenario deaktivieren
docker exec crowdsec cscli scenarios remove crowdsecurity/http-bad-user-agent
```

## CrowdSec Hub

CrowdSec hat einen Hub mit tausenden von Szenarien, Parsern und Collections:

https://hub.crowdsec.net/

### Beliebte Zusatz-Collections

```bash
# WordPress Protection
docker exec crowdsec cscli collections install crowdsecurity/wordpress

# Nextcloud Protection
docker exec crowdsec cscli collections install crowdsecurity/nextcloud

# SSH Protection (zusätzlich zu Fail2Ban)
docker exec crowdsec cscli collections install crowdsecurity/sshd

# Apache/Nginx Protection
docker exec crowdsec cscli collections install crowdsecurity/nginx

# Base HTTP Protection
docker exec crowdsec cscli collections install crowdsecurity/base-http-scenarios
```

## Central API (optional)

Registriere deinen CrowdSec bei der Central API für:
- Community Threat Intelligence
- Konsole zur Überwachung
- Shared IP Reputation

### Registrierung

```bash
# Auf dem Server
docker exec crowdsec cscli console enroll [your-enroll-key]
```

Enroll Key bekommst du auf: https://app.crowdsec.net/

## Traefik Bouncer Integration

Der Bouncer ist bereits in Traefik integriert via Middleware `crowdsec-bouncer`.

### Middleware auf Services anwenden

**Beispiel: Alle Services schützen**

In `traefik/config.yml` ist bereits die `secured` Chain definiert:

```yaml
secured:
  chain:
    middlewares:
    - crowdsec-bouncer  # Blockiert gebannte IPs
    - default-whitelist
    - default-headers
```

**Service-spezifisch schützen:**

```yaml
labels:
  - "traefik.http.routers.myservice-secure.middlewares=crowdsec-bouncer"
```

### Bouncer Logs anzeigen

```bash
docker logs traefik-bouncer -f
```

### Bouncer Status

```bash
docker exec traefik-bouncer wget -qO- http://localhost:8080/api/v1/ping
```

## rkhunter - Rootkit Detection

rkhunter scannt das System nach Rootkits, Backdoors und lokalen Exploits.

### Manueller Scan

```bash
ssh root@docker.fwv-raura.ch
rkhunter --check --skip-keypress
```

### Reports anzeigen

```bash
cat /var/log/rkhunter.log
```

### Automatischer täglicher Scan

rkhunter läuft automatisch täglich via cron. Reports werden per E-Mail gesendet (falls konfiguriert).

### Konfiguration

```bash
nano /etc/rkhunter.conf
```

Wichtige Optionen:
```conf
MAIL-ON-WARNING=root@localhost
UPDATE_MIRRORS=1
MIRRORS_MODE=0
WEB_CMD="/bin/false"
```

## Lynis - Security Auditing

Lynis ist ein umfassendes Security Audit Tool.

### Audit durchführen

```bash
ssh root@docker.fwv-raura.ch
lynis audit system
```

### Report anzeigen

```bash
cat /var/log/lynis.log
cat /var/log/lynis-report.dat
```

### Häufige Empfehlungen

Lynis gibt Sicherheitsempfehlungen. Typische Findings:

**1. SSH Hardening**
```bash
nano /etc/ssh/sshd_config

# Empfohlene Einstellungen:
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding no
```

**2. Kernel Hardening**
```bash
nano /etc/sysctl.conf

# Empfohlene Einstellungen:
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1
```

Dann anwenden:
```bash
sysctl -p
```

## Automatische Sicherheitsupdates

Unattended-Upgrades ist konfiguriert für automatische Sicherheitsupdates.

### Status prüfen

```bash
systemctl status unattended-upgrades
```

### Logs anzeigen

```bash
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

### Konfiguration

```bash
nano /etc/apt/apt.conf.d/50unattended-upgrades
```

## Fail2Ban

Fail2Ban läuft parallel zu CrowdSec und schützt speziell SSH.

### Status

```bash
fail2ban-client status
fail2ban-client status sshd
```

### Gebannte IPs anzeigen

```bash
fail2ban-client status sshd
```

### IP entbannen

```bash
fail2ban-client set sshd unbanip 1.2.3.4
```

### Logs

```bash
tail -f /var/log/fail2ban.log
```

## Monitoring & Alerts

### CrowdSec Prometheus Metrics

CrowdSec exportiert Prometheus Metrics auf Port 6060.

Optional: Prometheus + Grafana Stack hinzufügen für Monitoring.

### Alert-Benachrichtigungen

CrowdSec kann Alerts an verschiedene Services senden:

- Slack
- Email
- Discord
- Splunk
- etc.

Konfiguration via Notifications:

```bash
docker exec crowdsec cscli notifications add my-slack-notif \
  --type slack \
  --url "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## Best Practices

### 1. Regelmäßige Security Audits

```bash
# Weekly
lynis audit system

# Monthly
rkhunter --check

# Check CrowdSec Metrics
docker exec crowdsec cscli metrics
```

### 2. Log Review

```bash
# CrowdSec Alerts
docker exec crowdsec cscli alerts list

# Traefik Access Logs (Errors only)
docker exec traefik cat /var/log/traefik/access.log | grep -E "40[0-9]|50[0-9]"

# System Auth Logs
journalctl -u ssh -n 100
```

### 3. Whitelist vertrauenswürdiger IPs

Füge deine eigenen IPs zur Whitelist hinzu:

```bash
nano /opt/docker/crowdsec/config/parsers/s02-enrich/whitelist.yaml
```

### 4. CrowdSec Updates

```bash
# Collections updaten
docker exec crowdsec cscli hub update
docker exec crowdsec cscli hub upgrade

# Container Image updaten
docker-compose pull crowdsec traefik-bouncer
docker-compose up -d crowdsec traefik-bouncer
```

### 5. Backup der CrowdSec Config

```bash
tar -czf crowdsec-backup-$(date +%Y%m%d).tar.gz /opt/docker/crowdsec/config
```

## Troubleshooting

### CrowdSec startet nicht

```bash
# Logs prüfen
docker logs crowdsec

# Config validieren
docker exec crowdsec cscli config show
```

### Bouncer blockiert legitime IPs

```bash
# IP sofort entbannen
docker exec crowdsec cscli decisions delete --ip 1.2.3.4

# Zur Whitelist hinzufügen (siehe oben)
```

### Hohe False-Positive Rate

```bash
# Scenario Threshold anpassen
docker exec crowdsec cscli scenarios inspect crowdsecurity/http-sensitive-files

# Scenario deaktivieren
docker exec crowdsec cscli scenarios remove crowdsecurity/http-sensitive-files
```

### Bouncer-Logs zeigen Fehler

```bash
# Bouncer Logs
docker logs traefik-bouncer

# API Key prüfen
echo $CROWDSEC_BOUNCER_KEY_TRAEFIK

# Bouncer neu starten
docker-compose restart traefik-bouncer
```

## Weitere Informationen

- CrowdSec Dokumentation: https://docs.crowdsec.net/
- CrowdSec Hub: https://hub.crowdsec.net/
- Traefik Bouncer: https://github.com/fbonalair/traefik-crowdsec-bouncer
- Lynis: https://cisofy.com/lynis/
- rkhunter: http://rkhunter.sourceforge.net/

## Nützliche Befehle Zusammenfassung

```bash
# CrowdSec Status
docker exec crowdsec cscli metrics
docker exec crowdsec cscli decisions list
docker exec crowdsec cscli alerts list

# IP Management
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 4h
docker exec crowdsec cscli decisions delete --ip 1.2.3.4

# Collections
docker exec crowdsec cscli collections list
docker exec crowdsec cscli hub update
docker exec crowdsec cscli hub upgrade

# Security Scans
lynis audit system
rkhunter --check --skip-keypress

# Logs
docker logs crowdsec -f
docker logs traefik-bouncer -f
fail2ban-client status
```
