#!/bin/sh
set -e

echo "=== [INIT] Attente que Forgejo soit prêt ==="

# Attendre que l'API réponde
MAX_ATTEMPTS=60
ATTEMPT=0

until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "ERREUR: Timeout après ${MAX_ATTEMPTS} tentatives"
    exit 1
  fi
  echo "Forgejo pas encore prêt... (tentative $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 5
done

echo "✅ Forgejo répond !"

# Attendre que Forgejo soit vraiment prêt (pas juste healthcheck)
sleep 10

# Variables
ADMIN_USER="${ADMIN_USERNAME:-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"
ADMIN_FULLNAME="${ADMIN_FULLNAME:-Administrator}"
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"

echo "Configuration:"
echo "  - Admin user: $ADMIN_USER"
echo "  - OAuth redirect: $OAUTH_REDIRECT_URI"

# Créer l'utilisateur admin
echo "Création utilisateur admin..."

wget --quiet --output-document=- --server-response \
  --header='Content-Type: application/json' \
  --post-data="{
    \"username\": \"$ADMIN_USER\",
    \"password\": \"$ADMIN_PASS\",
    \"email\": \"$ADMIN_EMAIL\",
    \"full_name\": \"$ADMIN_FULLNAME\",
    \"must_change_password\": false,
    \"admin\": true
  }" \
  http://localhost:3000/api/v1/admin/users 2>&1 | grep -q "201\|200\|422" && echo "✅ Admin OK" || echo "⚠️ Admin échoué"

# Récupérer token
echo "Récupération token admin..."

TOKEN_RESPONSE=$(wget --quiet --output-document=- \
  --auth-no-challenge --user="$ADMIN_USER" --password="$ADMIN_PASS" \
  --header='Content-Type: application/json' \
  --post-data='{"name": "init-token-auto"}' \
  http://localhost:3000/api/v1/users/$ADMIN_USER/tokens 2>/dev/null || echo "{}")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Échec token admin"
  exit 1
fi

echo "✅ Token obtenu"

# Créer OAuth
echo "Création application OAuth..."

OAUTH_RESPONSE=$(wget --quiet --output-document=- \
  --header="Authorization: token $ADMIN_TOKEN" \
  --header='Content-Type: application/json' \
  --post-data="{
    \"name\": \"Woodpecker CI\",
    \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"],
    \"confidential_client\": true,
    \"scopes\": [\"repo,user:email,read:org,read:repository,write:repository\"]
  }" \
  http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 2>/dev/null || echo "{}")

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id' 2>/dev/null)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret' 2>/dev/null)

if [ "$OAUTH_CLIENT_ID" != "null" ] && [ -n "$OAUTH_CLIENT_ID" ]; then
  echo "✅ OAuth créé !"
  echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
  echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
  
  # Export vers fichier partagé
  mkdir -p /shared
  cat > /shared/.oauth-credentials << EOF
export WOODPECKER_FORGEJO_CLIENT="$OAUTH_CLIENT_ID"
export WOODPECKER_FORGEJO_SECRET="$OAUTH_CLIENT_SECRET"
EOF
  chmod 644 /shared/.oauth-credentials
  echo "✅ OAuth exporté vers /shared/.oauth-credentials"
fi

echo "✅ Initialisation terminée !"