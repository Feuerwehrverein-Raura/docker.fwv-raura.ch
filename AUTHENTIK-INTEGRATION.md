# Authentik Integration Guide

Diese Anleitung zeigt, wie du Authentik als zentralen Identity Provider (SSO) für alle Services einrichtest.

## Voraussetzungen

- Alle Services sind deployed und laufen
- Authentik ist erreichbar unter https://auth.fwv-raura.ch
- Du hast Admin-Zugriff auf Authentik, Nextcloud und Portainer

## 1. Authentik Ersteinrichtung

### Erster Login

1. Öffne https://auth.fwv-raura.ch
2. Beim ersten Start generiert Authentik einen Bootstrap-Token
3. Token aus den Logs holen:
   ```bash
   ssh root@docker.fwv-raura.ch
   cd /opt/docker
   docker-compose logs authentik-server | grep "Bootstrap"
   ```
4. Mit `akadmin` und dem Bootstrap-Token einloggen
5. **SOFORT** ein neues sicheres Admin-Passwort setzen!

### Default Tenant konfigurieren

1. Gehe zu **System** → **Tenants**
2. Bearbeite den "Default" Tenant
3. Setze:
   - **Domain**: `auth.fwv-raura.ch`
   - **Branding Title**: `Feuerwehrverein Raura SSO`

## 2. Nextcloud mit Authentik verbinden

### In Authentik: OAuth2 Provider erstellen

1. Gehe zu **Applications** → **Providers** → **Create**
2. Wähle **OAuth2/OpenID Provider**
3. Konfiguration:
   - **Name**: `Nextcloud`
   - **Authorization flow**: `implicit-consent` (Auto-genehmigung für vertrauenswürdige Apps)
   - **Client type**: `Confidential`
   - **Redirect URIs**:
     ```
     https://cloud.fwv-raura.ch/apps/user_oidc/code
     ```
   - **Scopes**: `openid`, `email`, `profile`
4. Speichern und notiere:
   - **Client ID**
   - **Client Secret**

### Application in Authentik erstellen

1. Gehe zu **Applications** → **Applications** → **Create**
2. Konfiguration:
   - **Name**: `Nextcloud`
   - **Slug**: `nextcloud`
   - **Provider**: Den gerade erstellten "Nextcloud" Provider wählen
   - **Launch URL**: `https://cloud.fwv-raura.ch`
   - **Icon**: Optional ein Nextcloud Icon hochladen
3. Speichern

### In Nextcloud: OpenID Connect App installieren

```bash
ssh root@docker.fwv-raura.ch
docker exec -u www-data nextcloud php occ app:install user_oidc
docker exec -u www-data nextcloud php occ app:enable user_oidc
```

### In Nextcloud: Provider konfigurieren

**Option 1: Via Nextcloud Web-UI** (Empfohlen)

1. Login als Admin auf https://cloud.fwv-raura.ch
2. Gehe zu **Settings** → **Administration** → **OpenID Connect**
3. Klicke **Add OpenID Provider**:
   - **Identifier**: `Authentik`
   - **Client ID**: Von Authentik kopiert
   - **Client Secret**: Von Authentik kopiert
   - **Discovery URL**: `https://auth.fwv-raura.ch/application/o/nextcloud/.well-known/openid-configuration`
4. Speichern

**Option 2: Via config.php**

```bash
# Auf dem Server
ssh root@docker.fwv-raura.ch
nano /opt/docker/nextcloud/config/config.php
```

Füge hinzu:

```php
'user_oidc' => [
  'single_logout' => false,
  'auto_provision' => true,
  'soft_auto_provision' => true,
],
'oidc_login_provider_url' => 'https://auth.fwv-raura.ch/application/o/nextcloud/',
'oidc_login_client_id' => 'DEINE_CLIENT_ID',
'oidc_login_client_secret' => 'DEIN_CLIENT_SECRET',
'oidc_login_auto_redirect' => false,
'oidc_login_end_session_redirect' => false,
'oidc_login_button_text' => 'Login mit Authentik',
'oidc_login_hide_password_form' => false,
'oidc_login_use_id_token' => true,
'oidc_login_attributes' => [
  'id' => 'sub',
  'name' => 'name',
  'mail' => 'email',
  'groups' => 'groups',
],
'oidc_login_default_group' => 'oidc_users',
'oidc_login_use_external_storage' => false,
'oidc_login_scope' => 'openid profile email groups',
'oidc_login_proxy_ldap' => false,
'oidc_login_disable_registration' => false,
'oidc_login_redir_fallback' => false,
'oidc_login_tls_verify' => true,
```

Dann Nextcloud neu starten:

```bash
docker-compose restart nextcloud
```

### Testen

1. Logout aus Nextcloud
2. Du solltest jetzt einen "Login mit Authentik" Button sehen
3. Klicke darauf → Weiterleitung zu Authentik
4. Login mit Authentik Account
5. Automatische Weiterleitung zurück zu Nextcloud

## 3. Portainer mit Authentik verbinden

### In Authentik: OAuth2 Provider für Portainer erstellen

1. Gehe zu **Applications** → **Providers** → **Create**
2. Wähle **OAuth2/OpenID Provider**
3. Konfiguration:
   - **Name**: `Portainer`
   - **Authorization flow**: `implicit-consent`
   - **Client type**: `Confidential`
   - **Redirect URIs**:
     ```
     https://portainer.fwv-raura.ch
     ```
   - **Scopes**: `openid`, `email`, `profile`
4. Speichern und notiere:
   - **Client ID**
   - **Client Secret**

### Application in Authentik erstellen

1. Gehe zu **Applications** → **Applications** → **Create**
2. Konfiguration:
   - **Name**: `Portainer`
   - **Slug**: `portainer`
   - **Provider**: Den "Portainer" Provider wählen
   - **Launch URL**: `https://portainer.fwv-raura.ch`
3. Speichern

### In Portainer: OAuth konfigurieren

1. Login als Admin auf https://portainer.fwv-raura.ch
2. Gehe zu **Settings** → **Authentication**
3. Wähle **OAuth** als Authentication method
4. Konfiguration:
   - **Provider**: `Custom`
   - **Client ID**: Von Authentik kopiert
   - **Client Secret**: Von Authentik kopiert
   - **Authorization URL**: `https://auth.fwv-raura.ch/application/o/authorize/`
   - **Access Token URL**: `https://auth.fwv-raura.ch/application/o/token/`
   - **Resource URL**: `https://auth.fwv-raura.ch/application/o/userinfo/`
   - **Redirect URL**: `https://portainer.fwv-raura.ch`
   - **Logout URL**: `https://auth.fwv-raura.ch/application/o/portainer/end-session/`
   - **User identifier**: `sub`
   - **Scopes**: `openid email profile`
5. **Automatic user provisioning**: Aktivieren
6. Speichern

### Testen

1. Logout aus Portainer
2. Klicke auf "Login with OAuth"
3. Weiterleitung zu Authentik
4. Login mit Authentik Account
5. Automatische Weiterleitung zurück zu Portainer

## 4. n8n mit Authentik verbinden

### In Authentik: OAuth2 Provider für n8n erstellen

1. Gehe zu **Applications** → **Providers** → **Create**
2. Wähle **OAuth2/OpenID Provider**
3. Konfiguration:
   - **Name**: `n8n`
   - **Authorization flow**: `implicit-consent`
   - **Client type**: `Confidential`
   - **Redirect URIs**:
     ```
     https://n8n.fwv-raura.ch/rest/oauth2-credential/callback
     ```
   - **Scopes**: `openid`, `email`, `profile`
4. Speichern und notiere:
   - **Client ID**
   - **Client Secret**

### Application in Authentik erstellen

1. Gehe zu **Applications** → **Applications** → **Create**
2. Konfiguration:
   - **Name**: `n8n`
   - **Slug**: `n8n`
   - **Provider**: Den "n8n" Provider wählen
   - **Launch URL**: `https://n8n.fwv-raura.ch`
3. Speichern

### n8n Umgebungsvariablen anpassen

n8n unterstützt externe OAuth2 Provider über Umgebungsvariablen.

**Auf dem Server:**

```bash
ssh root@docker.fwv-raura.ch
nano /opt/docker/.env
```

Füge für n8n hinzu:

```bash
# n8n OAuth via Authentik
N8N_SSO_OIDC_ENABLED=true
N8N_SSO_OIDC_CLIENT_ID=DEINE_CLIENT_ID
N8N_SSO_OIDC_CLIENT_SECRET=DEIN_CLIENT_SECRET
N8N_SSO_OIDC_ISSUER=https://auth.fwv-raura.ch/application/o/n8n/
N8N_SSO_OIDC_AUTHORIZATION_URL=https://auth.fwv-raura.ch/application/o/authorize/
N8N_SSO_OIDC_TOKEN_URL=https://auth.fwv-raura.ch/application/o/token/
N8N_SSO_OIDC_USERINFO_URL=https://auth.fwv-raura.ch/application/o/userinfo/
N8N_SSO_OIDC_SCOPE=openid email profile
```

**docker-compose.yml erweitern:**

Bearbeite `/opt/docker/docker-compose.yml` und füge die n8n Umgebungsvariablen hinzu:

```yaml
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    networks:
      - proxy
    environment:
      - N8N_HOST=${N8N_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${N8N_DOMAIN}/
      - GENERIC_TIMEZONE=${TIMEZONE}
      # OAuth via Authentik
      - N8N_SSO_OIDC_ENABLED=${N8N_SSO_OIDC_ENABLED:-false}
      - N8N_SSO_OIDC_CLIENT_ID=${N8N_SSO_OIDC_CLIENT_ID}
      - N8N_SSO_OIDC_CLIENT_SECRET=${N8N_SSO_OIDC_CLIENT_SECRET}
      - N8N_SSO_OIDC_ISSUER=${N8N_SSO_OIDC_ISSUER}
      - N8N_SSO_OIDC_AUTHORIZATION_URL=${N8N_SSO_OIDC_AUTHORIZATION_URL}
      - N8N_SSO_OIDC_TOKEN_URL=${N8N_SSO_OIDC_TOKEN_URL}
      - N8N_SSO_OIDC_USERINFO_URL=${N8N_SSO_OIDC_USERINFO_URL}
      - N8N_SSO_OIDC_SCOPE=${N8N_SSO_OIDC_SCOPE}
```

Container neu starten:

```bash
docker-compose up -d n8n
```

## 5. Traefik Forward Auth (Alle Services schützen)

Mit Forward Auth kannst du **alle** Services hinter Authentik schützen, auch solche ohne native OAuth-Unterstützung.

### Authentik Outpost erstellen

1. In Authentik: Gehe zu **Applications** → **Outposts**
2. Erstelle neuen **Proxy Outpost**:
   - **Name**: `Traefik Forward Auth`
   - **Type**: `Proxy`
   - **Integration**: Kein spezielles Integration nötig
3. Speichern

### Provider für Forward Auth erstellen

1. Gehe zu **Applications** → **Providers** → **Create**
2. Wähle **Proxy Provider**
3. Konfiguration:
   - **Name**: `Traefik Forward Auth`
   - **Authorization flow**: Wähle einen Flow (z.B. "default-authentication-flow")
   - **External host**: `https://auth.fwv-raura.ch`
   - **Mode**: `Forward auth (single application)`
4. Speichern

### Traefik Middleware konfigurieren

Bearbeite `/opt/docker/traefik/config.yml`:

```yaml
http:
  middlewares:
    authentik-auth:
      forwardAuth:
        address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version
```

### Services schützen

Um einen Service mit Authentik zu schützen, füge die Middleware hinzu.

**Beispiel: Traefik Dashboard schützen**

In `docker-compose.yml`:

```yaml
  traefik:
    # ...
    labels:
      # ... bestehende Labels ...
      - "traefik.http.routers.traefik-secure.middlewares=authentik-auth"
```

**Beispiel: Ein beliebiger Service**

```yaml
labels:
  - "traefik.http.routers.myservice-secure.middlewares=authentik-auth"
```

Container neu starten:

```bash
docker-compose restart traefik
```

## 6. Benutzerverwaltung in Authentik

### Benutzer anlegen

1. Gehe zu **Directory** → **Users**
2. Klicke **Create**
3. Fülle aus:
   - **Username**
   - **Name**
   - **Email**
   - **Groups** (optional)
4. Setze Passwort oder sende Einladungslink

### Gruppen erstellen

1. Gehe zu **Directory** → **Groups**
2. Klicke **Create**
3. Namen vergeben (z.B. "Admins", "Users", "Feuerwehr")
4. Benutzer zuweisen

### Gruppen-basierte Zugriffskontrolle

In jeder Application kannst du festlegen, welche Gruppen Zugriff haben:

1. Bearbeite die Application
2. **Policy Bindings** → **Bind existing policy**
3. Erstelle eine **Group Policy**
4. Wähle erlaubte Gruppen

## 7. Best Practices

### Sicherheit

- ✅ Ändere das Authentik Admin-Passwort sofort nach dem ersten Login
- ✅ Aktiviere 2FA für Admin-Accounts
- ✅ Erstelle separate Admin-Accounts pro Person (kein shared account)
- ✅ Nutze starke Passwörter oder Passkeys
- ✅ Aktiviere Login-Benachrichtigungen per Email
- ✅ Überprüfe regelmäßig die Audit-Logs

### Backup

Sichere regelmäßig die Authentik PostgreSQL Datenbank:

```bash
docker exec authentik-postgresql pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql
```

### Updates

Authentik automatisch via Docker Compose updaten:

```bash
cd /opt/docker
docker-compose pull authentik-server authentik-worker
docker-compose up -d authentik-server authentik-worker
```

## Troubleshooting

### Redirect Loop

Wenn du in einem Redirect Loop feststeckst:

1. Lösche Browser Cookies für die Domain
2. Prüfe dass die Redirect URIs exakt übereinstimmen
3. Prüfe dass `OVERWRITEPROTOCOL=https` in Nextcloud gesetzt ist

### Token Errors

Bei "Invalid Token" Fehlern:

1. Prüfe dass die Client ID/Secret korrekt sind
2. Prüfe dass die Scopes korrekt konfiguriert sind
3. Prüfe Authentik Logs: `docker-compose logs authentik-server`

### 502 Bad Gateway

Wenn Authentik nicht erreichbar ist:

```bash
docker-compose logs authentik-server
docker-compose logs authentik-postgresql
docker-compose ps
```

Prüfe dass PostgreSQL healthy ist.

## Weitere Informationen

- Authentik Dokumentation: https://goauthentik.io/docs/
- Nextcloud OIDC App: https://github.com/nextcloud/user_oidc
- Portainer OAuth: https://docs.portainer.io/admin/settings/authentication/oauth
- n8n SSO: https://docs.n8n.io/hosting/configuration/environment-variables/sso/
