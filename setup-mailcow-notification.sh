#!/bin/bash

# Mailcow API Setup Script für notification@fwv-raura.ch
# Host: mail.test.juroct.net

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MAILCOW_HOST="mail.test.juroct.net"
MAILCOW_API_URL="https://${MAILCOW_HOST}/api/v1"
DOMAIN="fwv-raura.ch"
MAILBOX_USER="notification"
MAILBOX_NAME="Notifications FWV Raura"
MAILBOX_QUOTA="1024" # MB

# API-Key prüfen
if [ -z "$MAILCOW_API_KEY" ]; then
    echo -e "${RED}Error: MAILCOW_API_KEY Umgebungsvariable nicht gesetzt!${NC}"
    echo ""
    echo "Bitte setze den API-Key:"
    echo "  export MAILCOW_API_KEY='dein-api-key-hier'"
    echo ""
    echo "API-Key generieren:"
    echo "  1. Öffne: https://${MAILCOW_HOST}"
    echo "  2. Login als Admin"
    echo "  3. Gehe zu: System → Configuration → API"
    echo "  4. Erstelle neuen API-Key mit Berechtigungen:"
    echo "     - Domains (read/write)"
    echo "     - Mailboxes (read/write)"
    exit 1
fi

# Passwort generieren
if [ -z "$MAILBOX_PASSWORD" ]; then
    MAILBOX_PASSWORD=$(openssl rand -base64 16)
    echo -e "${YELLOW}Generiertes Passwort: ${MAILBOX_PASSWORD}${NC}"
    echo -e "${YELLOW}Bitte speichern!${NC}"
    echo ""
fi

echo "========================================="
echo "Mailcow Notification Mailbox Setup"
echo "========================================="
echo "Host:     ${MAILCOW_HOST}"
echo "Domain:   ${DOMAIN}"
echo "Mailbox:  ${MAILBOX_USER}@${DOMAIN}"
echo "========================================="
echo ""

# Schritt 1: Prüfe ob Domain existiert
echo -e "${YELLOW}[1/3] Prüfe Domain ${DOMAIN}...${NC}"
DOMAIN_CHECK=$(curl -k -s -X GET \
    "${MAILCOW_API_URL}/get/domain/${DOMAIN}" \
    -H "X-API-Key: ${MAILCOW_API_KEY}" \
    -H "Content-Type: application/json")

if echo "$DOMAIN_CHECK" | grep -q "\"domain_name\":\"${DOMAIN}\""; then
    echo -e "${GREEN}✓ Domain ${DOMAIN} existiert bereits${NC}"
else
    echo -e "${YELLOW}Domain ${DOMAIN} nicht gefunden. Erstelle Domain...${NC}"

    DOMAIN_RESPONSE=$(curl -k -s -X POST \
        "${MAILCOW_API_URL}/add/domain" \
        -H "X-API-Key: ${MAILCOW_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"domain\": \"${DOMAIN}\",
            \"description\": \"Feuerwehrverein Raura\",
            \"aliases\": 400,
            \"mailboxes\": 10,
            \"defquota\": 1024,
            \"maxquota\": 10240,
            \"quota\": 10240,
            \"active\": 1,
            \"rl_value\": 10,
            \"rl_frame\": \"s\",
            \"backupmx\": 0,
            \"relay_all_recipients\": 0
        }")

    if echo "$DOMAIN_RESPONSE" | grep -q "\"type\":\"success\""; then
        echo -e "${GREEN}✓ Domain ${DOMAIN} erfolgreich erstellt${NC}"
    else
        echo -e "${RED}✗ Fehler beim Erstellen der Domain:${NC}"
        echo "$DOMAIN_RESPONSE" | jq '.' 2>/dev/null || echo "$DOMAIN_RESPONSE"
        exit 1
    fi
fi

echo ""

# Schritt 2: Prüfe ob Mailbox existiert
echo -e "${YELLOW}[2/3] Prüfe Mailbox ${MAILBOX_USER}@${DOMAIN}...${NC}"
MAILBOX_CHECK=$(curl -k -s -X GET \
    "${MAILCOW_API_URL}/get/mailbox/${MAILBOX_USER}@${DOMAIN}" \
    -H "X-API-Key: ${MAILCOW_API_KEY}" \
    -H "Content-Type: application/json")

if echo "$MAILBOX_CHECK" | grep -q "\"username\":\"${MAILBOX_USER}@${DOMAIN}\""; then
    echo -e "${GREEN}✓ Mailbox ${MAILBOX_USER}@${DOMAIN} existiert bereits${NC}"
    echo -e "${YELLOW}⚠ Passwort wird NICHT geändert${NC}"
else
    echo -e "${YELLOW}Mailbox ${MAILBOX_USER}@${DOMAIN} nicht gefunden. Erstelle Mailbox...${NC}"

    MAILBOX_RESPONSE=$(curl -k -s -X POST \
        "${MAILCOW_API_URL}/add/mailbox" \
        -H "X-API-Key: ${MAILCOW_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"local_part\": \"${MAILBOX_USER}\",
            \"domain\": \"${DOMAIN}\",
            \"name\": \"${MAILBOX_NAME}\",
            \"quota\": \"${MAILBOX_QUOTA}\",
            \"password\": \"${MAILBOX_PASSWORD}\",
            \"password2\": \"${MAILBOX_PASSWORD}\",
            \"active\": \"1\",
            \"force_pw_update\": \"0\",
            \"tls_enforce_in\": \"1\",
            \"tls_enforce_out\": \"1\"
        }")

    if echo "$MAILBOX_RESPONSE" | grep -q "\"type\":\"success\""; then
        echo -e "${GREEN}✓ Mailbox ${MAILBOX_USER}@${DOMAIN} erfolgreich erstellt${NC}"
    else
        echo -e "${RED}✗ Fehler beim Erstellen der Mailbox:${NC}"
        echo "$MAILBOX_RESPONSE" | jq '.' 2>/dev/null || echo "$MAILBOX_RESPONSE"
        exit 1
    fi
fi

echo ""

# Schritt 3: Zusammenfassung
echo -e "${YELLOW}[3/3] Zusammenfassung${NC}"
echo ""
echo "========================================="
echo -e "${GREEN}✓ Setup erfolgreich abgeschlossen!${NC}"
echo "========================================="
echo ""
echo "SMTP-Zugangsdaten:"
echo "  E-Mail:       ${MAILBOX_USER}@${DOMAIN}"
echo "  Passwort:     ${MAILBOX_PASSWORD}"
echo ""
echo "  SMTP Server:  ${MAILCOW_HOST}"
echo "  SMTP Port:    587 (STARTTLS) oder 465 (SSL/TLS)"
echo "  IMAP Server:  ${MAILCOW_HOST}"
echo "  IMAP Port:    993 (SSL/TLS)"
echo ""
echo "GitHub Secrets aktualisieren:"
echo "  EMAIL_FROM=notification@fwv-raura.ch"
echo "  SMTP_SERVER=${MAILCOW_HOST}"
echo "  SMTP_PORT=587"
echo "  SMTP_USER=notification@fwv-raura.ch"
echo "  SMTP_PASSWORD=${MAILBOX_PASSWORD}"
echo ""
echo "========================================="
