#!/bin/sh
set -e

# =============================================================================
# first-run-init.sh - Auto-init Forgejo avec export OAuth automatique
# =============================================================================

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

echo "✅ Forgejo répond ! Lancement initialisation..."

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

ADMIN_CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$ADMIN_USER\",
    \"password\": \"$ADMIN_PASS\",
    \"email\": \"$ADMIN_EMAIL\",
    \"full_name\": \"$ADMIN_FULLNAME\",
    \"must_change_password\": false,
    \"admin\": true
  }")

HTTP_CODE=$(echo "$ADMIN_CREATE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$ADMIN_CREATE_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Admin créé avec succès"
elif [ "$HTTP_CODE" = "422" ]; then
    echo "ℹ️ Admin existe déjà (normal)"
else
    echo "⚠️ Code HTTP inattendu: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
fi

# ──────────────────────────────────────────────
# Récupérer un token admin
# ──────────────────────────────────────────────

echo "Récupération token admin..."

# Vérifier si jq est disponible
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ ERREUR: jq n'est pas installé (nécessaire pour le parsing JSON)"
    exit 1
fi

TOKEN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/users/$ADMIN_USER/tokens \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d '{"name": "init-token-auto"}')

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1')

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

OAUTH_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$OAUTH_APP_NAME\",
    \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"],
    \"confidential_client\": true,
    \"scopes\": [\"$OAUTH_SCOPES\"]
  }")

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id')
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret')

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ]; then
  echo "ℹ️ Application OAuth probablement déjà existante"
  echo "Response: $OAUTH_RESPONSE"
else
  echo ""
  echo "============================================================="
  echo "  ✅ OAuth créé avec succès !"
  echo "============================================================="
  echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
  echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
  echo ""
  
  # ──────────────────────────────────────────────
  # EXPORT AUTOMATIQUE : Écrire dans volume partagé
  # ──────────────────────────────────────────────
  
  OAUTH_FILE="/shared/.oauth-credentials"
  
  # Créer le répertoire partagé si nécessaire
  mkdir -p /shared
  
  cat > "$OAUTH_FILE" << EOF
# OAuth credentials auto-générés par first-run-init.sh
# Ce fichier est lu automatiquement au démarrage de Woodpecker
export WOODPECKER_FORGEJO_CLIENT="$OAUTH_CLIENT_ID"
export WOODPECKER_FORGEJO_SECRET="$OAUTH_CLIENT_SECRET"
EOF
  
  chmod 644 "$OAUTH_FILE"
  
  echo "✅ Credentials OAuth exportés vers $OAUTH_FILE"
  echo "   Woodpecker les chargera automatiquement au démarrage"
  echo ""
  echo "Connectez-vous à Forgejo : ${FORGEJO_ROOT_URL:-http://localhost:5333}"
  echo "Utilisateur admin : $ADMIN_USER / $ADMIN_PASS"
  echo "============================================================="
  echo ""
fi

# ──────────────────────────────────────────────
# Créer un dépôt exemple avec notice
# ──────────────────────────────────────────────

echo "Création dépôt exemple 'documentation'..."
REPO_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/user/repos \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "documentation",
    "description": "Notice d'utilisation Forgejo + Woodpecker",
    "private": false,
    "auto_init": true,
    "default_branch": "main"
  }')

REPO_ID=$(echo "$REPO_RESPONSE" | jq -r '.id')
if [ "$REPO_ID" != "null" ] && [ -n "$REPO_ID" ]; then
    echo "✅ Dépôt documentation créé (ID: $REPO_ID)"
else
    echo "ℹ️ Dépôt documentation probablement déjà existant"
fi

echo ""
echo "============================================================="
echo "✅ Initialisation terminée avec succès !"
echo "============================================================="