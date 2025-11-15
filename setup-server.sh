#!/bin/bash

###############################################################################
# Server Setup Script für docker.fwv-raura.ch
#
# Dieses Skript installiert Docker, Docker Compose und bereitet den Server vor
# für die automatische Provisionierung mit Traefik, n8n, Nextcloud und Mailcow
###############################################################################

set -e

echo "=================================="
echo "Server Setup für docker.fwv-raura.ch"
echo "=================================="
echo ""

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion für farbigen Output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check ob als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    print_error "Bitte als root ausführen (sudo ./setup-server.sh)"
    exit 1
fi

# System Updates
print_info "Aktualisiere System Pakete..."
apt-get update -qq
apt-get upgrade -y -qq
print_success "System aktualisiert"

# Installiere erforderliche Pakete
print_info "Installiere erforderliche Pakete..."
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    htop \
    vim \
    ufw \
    fail2ban \
    rkhunter \
    lynis \
    unattended-upgrades \
    mailutils \
    postfix
print_success "Pakete installiert"

# Konfiguriere Automatische Sicherheitsupdates
print_info "Konfiguriere automatische Sicherheitsupdates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "only-on-error";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

print_success "Automatische Sicherheitsupdates konfiguriert"

# Konfiguriere rkhunter
print_info "Konfiguriere rkhunter..."
rkhunter --update || true
rkhunter --propupd || true
print_success "rkhunter konfiguriert"

# Docker Installation
if ! command -v docker &> /dev/null; then
    print_info "Installiere Docker..."

    # Füge Docker's official GPG key hinzu
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Füge Docker Repository hinzu (Debian)
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Installiere Docker Engine
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Starte Docker
    systemctl enable docker
    systemctl start docker

    print_success "Docker installiert"
else
    print_success "Docker bereits installiert"
fi

# Docker Compose Installation (standalone für ältere Systeme)
if ! command -v docker-compose &> /dev/null; then
    print_info "Installiere Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installiert"
else
    print_success "Docker Compose bereits installiert"
fi

# Erstelle Deployment Verzeichnis
DEPLOY_PATH="/opt/docker"
if [ ! -d "$DEPLOY_PATH" ]; then
    print_info "Erstelle Deployment Verzeichnis: $DEPLOY_PATH"
    mkdir -p "$DEPLOY_PATH"
    print_success "Verzeichnis erstellt"
else
    print_success "Deployment Verzeichnis existiert bereits"
fi

# Firewall Konfiguration
print_info "Konfiguriere Firewall (UFW)..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
print_success "Firewall konfiguriert"

# Fail2Ban Konfiguration
print_info "Konfiguriere Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban
print_success "Fail2Ban aktiviert"

# Erstelle acme.json für Traefik mit korrekten Rechten
print_info "Bereite Traefik acme.json vor..."
touch "$DEPLOY_PATH/traefik/acme.json"
chmod 600 "$DEPLOY_PATH/traefik/acme.json"
print_success "acme.json erstellt"

# Docker Netzwerke erstellen (falls nicht vorhanden)
print_info "Erstelle Docker Netzwerke..."
docker network create proxy 2>/dev/null || print_info "Netzwerk 'proxy' existiert bereits"
docker network create nextcloud 2>/dev/null || print_info "Netzwerk 'nextcloud' existiert bereits"
print_success "Docker Netzwerke bereit"

# Zeige installierte Versionen
echo ""
echo "=================================="
echo "Installation abgeschlossen!"
echo "=================================="
echo ""
echo "Installierte Versionen:"
echo "  Docker:         $(docker --version | cut -d ' ' -f3 | tr -d ',')"
echo "  Docker Compose: $(docker-compose --version | cut -d ' ' -f4 | tr -d ',')"
echo ""
echo "Deployment Pfad: $DEPLOY_PATH"
echo ""
print_success "Server ist bereit für Deployment!"
echo ""
echo "Nächste Schritte:"
echo "1. Kopiere .env.example nach $DEPLOY_PATH/.env"
echo "2. Bearbeite $DEPLOY_PATH/.env mit deinen Werten"
echo "3. Führe das Deployment aus: ./deploy.sh"
echo ""
