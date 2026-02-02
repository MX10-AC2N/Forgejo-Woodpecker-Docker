#!/bin/sh
set -e

echo "=== [INIT] Attente que Forgejo soit prêt ==="

# Attendre que l'API réponde (healthz) - timeout de 5 minutes
MAX_ATTEMPTS=60
ATTEMPT=0

until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "ERREUR: Timeout après ${MAX_ATTEMPTS} tentatives (5 minutes)"
    exit 1
  fi
  echo "Forgejo pas encore prêt... (tentative $ATTEMPT/$MAX_ATTEMPTS, sleep 5s)"
  sleep 5
done

echo "✅ Forgejo répond ! Vérification installation..."

# Vérifier si Forgejo est installé (pas en mode setup)
# En mode setup, l'API retourne 404 sur /api/v1/
for i in $(seq 1 30); do
  HTTP_CODE=$(wget --spider --server-response http://localhost:3000/api/v1/version 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}')
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Forgejo complètement initialisé !"
    break
  fi
  
  echo "Forgejo en cours d'installation... (tentative $i/30)"
  sleep 10
done

# Si toujours pas installé, créer la config par défaut
if [ "$HTTP_CODE" != "200" ]; then
  echo "ℹ️ Forgejo pas encore installé - création config automatique..."
  
  # Attendre un peu plus
  sleep 30
  
  # Vérifier à nouveau
  HTTP_CODE=$(wget --spider --server-response http://localhost:3000/api/v1/version 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}')
  
  if [ "$HTTP_CODE" != "200" ]; then
    echo "⚠️ Forgejo toujours pas initialisé - l'admin devra le configurer manuellement"
    exit 0
  fi
fi

# ──────────────────────────────────────────────
# Variables depuis .env avec valeurs par défaut
# ──────────────────────────────────────────────

ADMIN_USER="${ADMIN_USERNAME:-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"
ADMIN_FULLNAME="${ADMIN_FULLNAME:-Administrator}"

# Construire l'OAuth redirect URI dynamiquement
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"
OAUTH_APP_NAME="Woodpecker CI"
OAUTH_SCOPES="repo,user:email,read:org,read:repository,write:repository"

echo "Configuration:"
echo "  - Admin user: $ADMIN_USER"
echo "  - Admin email: $ADMIN_EMAIL"
echo "  - OAuth redirect: $OAUTH_REDIRECT_URI"

# ──────────────────────────────────────────────
# Créer l'utilisateur admin
# ──────────────────────────────────────────────

echo "Création utilisateur admin..."

ADMIN_CREATE_RESPONSE=$(wget --quiet --output-document=- --server-response \
  --header='Content-Type: application/json' \
  --post-data="{
    \"username\": \"$ADMIN_USER\",
    \"password\": \"$ADMIN_PASS\",
    \"email\": \"$ADMIN_EMAIL\",
    \"full_name\": \"$ADMIN_FULLNAME\",
    \"must_change_password\": false,
    \"admin\": true
  }" \
  http://localhost:3000/api/v1/admin/users 2>&1 || echo "")

if echo "$ADMIN_CREATE_RESPONSE" | grep -q "201\|200\|422"; then
    echo "✅ Admin créé ou existe déjà"
else
    echo "⚠️ Échec création admin"
    echo "$ADMIN_CREATE_RESPONSE"
fi

# ──────────────────────────────────────────────
# Récupérer un token admin
# ──────────────────────────────────────────────

echo "Récupération token admin..."

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ ERREUR: jq n'est pas installé"
    exit 1
fi

TOKEN_RESPONSE=$(wget --quiet --output-document=- \
  --auth-no-challenge --user="$ADMIN_USER" --password="$ADMIN_PASS" \
  --header='Content-Type: application/json' \
  --post-data='{"name": "init-token-auto"}' \
  http://localhost:3000/api/v1/users/$ADMIN_USER/tokens 2>/dev/null || echo "{}")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ ERREUR : impossible de récupérer le token admin"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Token admin obtenu"

# ──────────────────────────────────────────────
# Créer l'application OAuth pour Woodpecker
# ──────────────────────────────────────────────

echo "Création application OAuth Woodpecker..."

OAUTH_RESPONSE=$(wget --quiet --output-document=- \
  --header="Authorization: token $ADMIN_TOKEN" \
  --header='Content-Type: application/json' \
  --post-data="{
    \"name\": \"$OAUTH_APP_NAME\",
    \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"],
    \"confidential_client\": true,
    \"scopes\": [\"$OAUTH_SCOPES\"]
  }" \
  http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 2>/dev/null || echo "{}")

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id' 2>/dev/null)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret' 2>/dev/null)

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ]; then
  echo "ℹ️ Application OAuth probablement déjà existante"
else
  echo ""
  echo "============================================================="
  echo "  ✅ OAuth créé avec succès !"
  echo "============================================================="
  echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
  echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
  echo ""
  
  # Export vers fichier partagé
  OAUTH_FILE="/shared/.oauth-credentials"
  mkdir -p /shared
  
  cat > "$OAUTH_FILE" << EOF
# OAuth credentials auto-générés
export WOODPECKER_FORGEJO_CLIENT="$OAUTH_CLIENT_ID"
export WOODPECKER_FORGEJO_SECRET="$OAUTH_CLIENT_SECRET"
EOF
  
  chmod 644 "$OAUTH_FILE"
  echo "✅ Credentials OAuth exportés vers $OAUTH_FILE"
  echo "============================================================="
fi

# Créer un dépôt exemple
echo "Création dépôt exemple 'documentation'..."
wget --quiet --output-document=- \
  --header="Authorization: token $ADMIN_TOKEN" \
  --header='Content-Type: application/json' \
  --post-data='{
    "name": "documentation",
    "description": "Notice d'utilisation Forgejo + Woodpecker",
    "private": false,
    "auto_init": true,
    "default_branch": "main"
  }' \
  http://localhost:3000/api/v1/user/repos >/dev/null 2>&1 && echo "✅ Dépôt créé" || echo "ℹ️ Dépôt existe déjà"

echo "✅ Initialisation terminée avec succès !"