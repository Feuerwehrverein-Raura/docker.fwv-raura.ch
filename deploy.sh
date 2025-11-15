#!/bin/bash

###############################################################################
# Deployment Script für docker.fwv-raura.ch
#
# Deployed das komplette Docker Setup via SSH zum Server
###############################################################################

set -e

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}"
    echo ""
}

# Lade .env falls vorhanden (für lokales Testing)
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Server Konfiguration (aus .env oder Defaults)
SERVER_HOST=${SERVER_HOST:-"docker.fwv-raura.ch"}
SERVER_USER=${SERVER_USER:-"root"}
SERVER_PORT=${SERVER_PORT:-"22"}
DEPLOY_PATH=${DEPLOY_PATH:-"/opt/docker"}

print_header "Deployment zu $SERVER_HOST"

# Teste SSH Verbindung
print_info "Teste SSH Verbindung zu $SERVER_USER@$SERVER_HOST:$SERVER_PORT..."
if ! ssh -p "$SERVER_PORT" -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" exit 2>/dev/null; then
    print_error "SSH Verbindung fehlgeschlagen!"
    print_info "Bitte stelle sicher, dass:"
    echo "  1. Der SSH Key hinterlegt ist"
    echo "  2. Der Server erreichbar ist"
    echo "  3. Die Verbindungsdaten korrekt sind"
    exit 1
fi
print_success "SSH Verbindung erfolgreich"

# Erstelle temporäres Verzeichnis für Deployment
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

print_info "Bereite Deployment-Dateien vor..."

# Kopiere relevante Dateien
cp docker-compose.yml "$TEMP_DIR/"
cp -r traefik "$TEMP_DIR/"
cp .env.example "$TEMP_DIR/"

# Erstelle Verzeichnisstruktur
mkdir -p "$TEMP_DIR/n8n/data"
mkdir -p "$TEMP_DIR/nextcloud/db"
mkdir -p "$TEMP_DIR/nextcloud/html"
mkdir -p "$TEMP_DIR/nextcloud/data"
mkdir -p "$TEMP_DIR/nextcloud/config"
mkdir -p "$TEMP_DIR/nextcloud/apps"

print_success "Dateien vorbereitet"

# Erstelle Deployment Verzeichnis auf Server
print_info "Erstelle Verzeichnis auf Server..."
ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "mkdir -p $DEPLOY_PATH"
print_success "Verzeichnis erstellt"

# Sync Dateien zum Server
print_info "Synchronisiere Dateien zum Server..."
rsync -avz --delete \
    -e "ssh -p $SERVER_PORT" \
    --exclude '.git' \
    --exclude '.env' \
    --exclude 'traefik/acme.json' \
    --exclude 'n8n/data/*' \
    --exclude 'nextcloud/db/*' \
    --exclude 'nextcloud/html/*' \
    --exclude 'nextcloud/data/*' \
    --exclude 'nextcloud/config/*' \
    --exclude 'nextcloud/apps/*' \
    ./ "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/"
print_success "Dateien synchronisiert"

# Erstelle/Update acme.json mit korrekten Rechten
print_info "Konfiguriere Traefik acme.json..."
ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'ENDSSH'
cd /opt/docker-services
if [ ! -f traefik/acme.json ]; then
    touch traefik/acme.json
fi
chmod 600 traefik/acme.json
ENDSSH
print_success "acme.json konfiguriert"

# Prüfe ob .env existiert
print_info "Prüfe .env Konfiguration auf dem Server..."
if ! ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "[ -f $DEPLOY_PATH/.env ]"; then
    print_error ".env Datei fehlt auf dem Server!"
    echo ""
    echo "Bitte erstelle eine .env Datei auf dem Server:"
    echo "  1. SSH zum Server: ssh $SERVER_USER@$SERVER_HOST"
    echo "  2. Kopiere Template: cp $DEPLOY_PATH/.env.example $DEPLOY_PATH/.env"
    echo "  3. Bearbeite Werte: nano $DEPLOY_PATH/.env"
    echo "  4. Führe Deployment erneut aus"
    echo ""
    exit 1
fi
print_success ".env existiert"

# Erstelle Docker Netzwerke falls nicht vorhanden
print_info "Erstelle Docker Netzwerke..."
ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'ENDSSH'
docker network create proxy 2>/dev/null || true
docker network create nextcloud 2>/dev/null || true
ENDSSH
print_success "Netzwerke bereit"

# Frage ob Container gestartet werden sollen
echo ""
read -p "Möchtest du die Container jetzt starten/neustarten? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Starte Container..."
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'ENDSSH'
cd /opt/docker-services
docker-compose pull
docker-compose up -d
docker-compose ps
ENDSSH
    print_success "Container gestartet"

    echo ""
    print_header "Deployment erfolgreich!"
    echo ""
    echo "Services sind erreichbar unter:"
    echo "  Traefik Dashboard: https://traefik.fwv-raura.ch"
    echo "  n8n:               https://n8n.fwv-raura.ch"
    echo "  Nextcloud:         https://cloud.fwv-raura.ch"
    echo ""
    echo "Logs anzeigen:"
    echo "  ssh $SERVER_USER@$SERVER_HOST 'cd $DEPLOY_PATH && docker-compose logs -f'"
    echo ""
else
    print_info "Container wurden nicht gestartet"
    echo ""
    echo "Um die Container später zu starten:"
    echo "  ssh $SERVER_USER@$SERVER_HOST 'cd $DEPLOY_PATH && docker-compose up -d'"
    echo ""
fi
