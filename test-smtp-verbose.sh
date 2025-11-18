#!/bin/bash

# Verbose SMTP Test mit detaillierter Fehlerausgabe

set +e  # Fehler nicht sofort abbrechen

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd /opt/docker

echo "========================================="
echo "SMTP Verbose Test"
echo "========================================="

# Variablen aus .env extrahieren (ohne source)
SMTP_SERVER=$(grep "^SMTP_SERVER=" .env | cut -d= -f2)
SMTP_PORT=$(grep "^SMTP_PORT=" .env | cut -d= -f2)
SMTP_USER=$(grep "^SMTP_USER=" .env | cut -d= -f2)
SMTP_PASSWORD=$(grep "^SMTP_PASSWORD=" .env | cut -d= -f2)
EMAIL_FROM=$(grep "^EMAIL_FROM=" .env | cut -d= -f2)
EMAIL_TO=$(grep "^EMAIL_TO=" .env | cut -d= -f2)

echo -e "${BLUE}Konfiguration:${NC}"
echo "  Server:   ${SMTP_SERVER}"
echo "  Port:     ${SMTP_PORT}"
echo "  User:     ${SMTP_USER}"
echo "  From:     ${EMAIL_FROM}"
echo "  To:       ${EMAIL_TO}"
echo "  Password: $(echo ${SMTP_PASSWORD} | sed 's/./*/g') (${#SMTP_PASSWORD} Zeichen)"
echo ""

# Erstelle Test-Email
TEMP_MSG=$(mktemp)
cat > "$TEMP_MSG" <<EOF
From: ${EMAIL_FROM}
To: ${EMAIL_TO}
Subject: SMTP Test - $(date +%Y-%m-%d_%H:%M:%S)
Date: $(date -R)

SMTP Test erfolgreich!

Server: ${SMTP_SERVER}:${SMTP_PORT}
User: ${SMTP_USER}
Zeitpunkt: $(date)

---
docker.fwv-raura.ch
EOF

echo -e "${YELLOW}Sende Test-E-Mail mit curl (verbose)...${NC}"
echo ""

if [ "${SMTP_PORT}" = "587" ]; then
    # STARTTLS
    curl -v --ssl-reqd \
        --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
        --mail-from "${EMAIL_FROM}" \
        --mail-rcpt "${EMAIL_TO}" \
        --user "${SMTP_USER}:${SMTP_PASSWORD}" \
        --upload-file "$TEMP_MSG" 2>&1 | tee /tmp/smtp-test.log
    RESULT=$?
elif [ "${SMTP_PORT}" = "465" ]; then
    # SSL/TLS
    curl -v \
        --url "smtps://${SMTP_SERVER}:${SMTP_PORT}" \
        --mail-from "${EMAIL_FROM}" \
        --mail-rcpt "${EMAIL_TO}" \
        --user "${SMTP_USER}:${SMTP_PASSWORD}" \
        --upload-file "$TEMP_MSG" 2>&1 | tee /tmp/smtp-test.log
    RESULT=$?
fi

rm -f "$TEMP_MSG"

echo ""
echo "========================================="

if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Test erfolgreich! E-Mail wurde gesendet.${NC}"
    echo ""
    echo "Bitte prüfe das Postfach: ${EMAIL_TO}"
elif [ $RESULT -eq 55 ]; then
    echo -e "${RED}✗ Authentifizierungsfehler (Exit Code 55)${NC}"
    echo ""
    echo "Mögliche Ursachen:"
    echo "  1. Falsches Passwort im GitHub Secret SMTP_PASSWORD"
    echo "  2. Mailbox ${SMTP_USER} existiert nicht auf ${SMTP_SERVER}"
    echo "  3. Mailbox ist deaktiviert"
    echo ""
    echo "Nächste Schritte:"
    echo "  1. Prüfe in Mailcow: https://${SMTP_SERVER}"
    echo "  2. Gehe zu: Configuration → Mail setup → Mailboxes"
    echo "  3. Prüfe ob ${SMTP_USER} existiert und aktiv ist"
    echo "  4. Setze ggf. das Passwort neu und aktualisiere GitHub Secret"
else
    echo -e "${RED}✗ Test fehlgeschlagen (Exit Code ${RESULT})${NC}"
    echo ""
    echo "Letzte Zeilen des Logs:"
    tail -20 /tmp/smtp-test.log
fi

echo "========================================="
echo ""
echo "Vollständiges Log: /tmp/smtp-test.log"
