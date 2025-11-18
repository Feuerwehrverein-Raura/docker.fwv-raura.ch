#!/bin/bash

# SMTP Test Script für notification@fwv-raura.ch
# Testet die Verbindung zum Mailcow Server

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "SMTP Verbindungstest"
echo "========================================="

# Secrets aus .env laden (wird auf dem Server von GitHub Actions erstellt)
if [ -f "/opt/docker/.env" ]; then
    # Exportiere nur SMTP-relevante Variablen (sicherer als source)
    export $(grep -E '^(SMTP_|EMAIL_)' /opt/docker/.env | xargs)
    echo -e "${GREEN}✓ .env Datei gefunden${NC}"
else
    echo -e "${RED}✗ .env Datei nicht gefunden${NC}"
    echo "Bitte führe das Script auf dem Server aus: /opt/docker/"
    exit 1
fi

echo ""
echo "SMTP Konfiguration:"
echo "  Server:   ${SMTP_SERVER}"
echo "  Port:     ${SMTP_PORT}"
echo "  User:     ${SMTP_USER}"
echo "  From:     ${EMAIL_FROM}"
echo "  To:       ${EMAIL_TO}"
echo ""

# Test 1: DNS Auflösung
echo -e "${YELLOW}[1/3] Teste DNS Auflösung...${NC}"
if host ${SMTP_SERVER} > /dev/null 2>&1; then
    IP=$(host ${SMTP_SERVER} | grep "has address" | awk '{print $4}' | head -1)
    echo -e "${GREEN}✓ DNS OK: ${SMTP_SERVER} → ${IP}${NC}"
else
    echo -e "${RED}✗ DNS Fehler: ${SMTP_SERVER} kann nicht aufgelöst werden${NC}"
    exit 1
fi

echo ""

# Test 2: Port Erreichbarkeit
echo -e "${YELLOW}[2/3] Teste Port-Erreichbarkeit...${NC}"
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${SMTP_SERVER}/${SMTP_PORT}" 2>/dev/null; then
    echo -e "${GREEN}✓ Port ${SMTP_PORT} ist erreichbar${NC}"
else
    echo -e "${RED}✗ Port ${SMTP_PORT} ist nicht erreichbar${NC}"
    exit 1
fi

echo ""

# Test 3: SMTP Verbindung (mit STARTTLS)
echo -e "${YELLOW}[3/3] Teste SMTP-Verbindung...${NC}"

# Test mit curl (wenn verfügbar)
if command -v curl &> /dev/null; then
    TEMP_MSG=$(mktemp)
    cat > "$TEMP_MSG" <<EOF
From: ${EMAIL_FROM}
To: ${EMAIL_TO}
Subject: SMTP Test von docker.fwv-raura.ch
Date: $(date -R)

Dies ist eine automatische Test-E-Mail.

Der SMTP-Service auf docker.fwv-raura.ch wurde erfolgreich konfiguriert.

Server: ${SMTP_SERVER}:${SMTP_PORT}
User: ${SMTP_USER}

---
Gesendet von: docker.fwv-raura.ch
Zeitpunkt: $(date)
EOF

    if [ "${SMTP_PORT}" = "587" ]; then
        # STARTTLS (Port 587)
        RESULT=$(curl -v --ssl-reqd \
            --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
            --mail-from "${EMAIL_FROM}" \
            --mail-rcpt "${EMAIL_TO}" \
            --user "${SMTP_USER}:${SMTP_PASSWORD}" \
            --upload-file "$TEMP_MSG" 2>&1)
    elif [ "${SMTP_PORT}" = "465" ]; then
        # SSL/TLS (Port 465)
        RESULT=$(curl -v \
            --url "smtps://${SMTP_SERVER}:${SMTP_PORT}" \
            --mail-from "${EMAIL_FROM}" \
            --mail-rcpt "${EMAIL_TO}" \
            --user "${SMTP_USER}:${SMTP_PASSWORD}" \
            --upload-file "$TEMP_MSG" 2>&1)
    fi

    rm -f "$TEMP_MSG"

    if echo "$RESULT" | grep -q "250"; then
        echo -e "${GREEN}✓ SMTP-Verbindung erfolgreich!${NC}"
        echo -e "${GREEN}✓ Test-E-Mail wurde gesendet an: ${EMAIL_TO}${NC}"
    else
        echo -e "${RED}✗ SMTP-Verbindung fehlgeschlagen${NC}"
        echo "Debug-Ausgabe:"
        echo "$RESULT" | tail -20
        exit 1
    fi
else
    # Fallback: openssl Test
    echo "Test SMTP mit openssl..."
    if [ "${SMTP_PORT}" = "587" ]; then
        echo "QUIT" | timeout 5 openssl s_client -connect ${SMTP_SERVER}:${SMTP_PORT} -starttls smtp 2>&1 | grep -q "250"
    else
        echo "QUIT" | timeout 5 openssl s_client -connect ${SMTP_SERVER}:${SMTP_PORT} 2>&1 | grep -q "250"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SMTP-Server antwortet korrekt${NC}"
    else
        echo -e "${RED}✗ SMTP-Server antwortet nicht wie erwartet${NC}"
        exit 1
    fi
fi

echo ""
echo "========================================="
echo -e "${GREEN}✓ Alle Tests erfolgreich!${NC}"
echo "========================================="
echo ""
echo "Die SMTP-Konfiguration ist korrekt."
echo "Services können jetzt E-Mails versenden."
