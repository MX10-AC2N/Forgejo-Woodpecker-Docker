#!/bin/sh
# Pas de set -e : on veut voir les erreurs dans docker logs, pas crasher en silence

echo "[INIT] === Début first-run-init.sh ==="

# ── Attente que l'API réponde ────────────────────────────────────────────
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
MAX_ATTEMPTS=60

until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "[INIT] ERREUR: Timeout après ${MAX_ATTEMPTS} tentatives"
    exit 1
  fi
  echo "[INIT] Forgejo pas encore prêt... (tentative $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 5
done

echo "[INIT] Forgejo répond !"
sleep 5

# ── Variables ─────────────────────────────────────────────────────────────
ADMIN_USER="${ADMIN_USERNAME:-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"

echo "[INIT] Admin user : $ADMIN_USER"
echo "[INIT] OAuth redirect : $OAUTH_REDIRECT_URI"

# ── Récupérer un token API via Basic Auth ────────────────────────────────
# L'user existe déjà (créé par CLI dans entrypoint avant le serveur).
echo "[INIT] Récupération token admin..."

TOKEN_RESPONSE=$(wget --quiet --output-document=- \
  --auth-no-challenge --user="$ADMIN_USER" --password="$ADMIN_PASS" \
  --header='Content-Type: application/json' \
  --post-data='{"name": "init-token-auto"}' \
  http://localhost:3000/api/v1/users/$ADMIN_USER/tokens 2>&1) || true

echo "[INIT] Token response : $TOKEN_RESPONSE"

# Forgejo 14 retourne le token dans .sha1
ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "[INIT] sha1 vide, tentative .token..."
  ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token' 2>/dev/null)
fi

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "[INIT] ERREUR: Impossible d'obtenir un token admin"
  echo "[INIT] Response complète : $TOKEN_RESPONSE"
  exit 1
fi

echo "[INIT] Token obtenu : ${ADMIN_TOKEN:0:16}..."

# ── Créer l'application OAuth pour Woodpecker ────────────────────────────
echo "[INIT] Création application OAuth..."

OAUTH_RESPONSE=$(wget --quiet --output-document=- \
  --header="Authorization: token $ADMIN_TOKEN" \
  --header='Content-Type: application/json' \
  --post-data="{\"name\":\"Woodpecker CI\",\"redirect_uris\":[\"$OAUTH_REDIRECT_URI\"],\"confidential_client\":true,\"scopes\":[\"repo,user:email,read:org,read:repository,write:repository\"]}" \
  http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 2>&1) || true

echo "[INIT] OAuth response : $OAUTH_RESPONSE"

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id' 2>/dev/null)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret' 2>/dev/null)

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ]; then
  echo "[INIT] ERREUR: Échec création OAuth"
  exit 1
fi

# ── Export vers volume partagé ────────────────────────────────────────────
# Ce fichier est lu par wait-and-configure-oauth.sh dans woodpecker-server
echo "[INIT] OAuth créé avec succès !"
echo "[INIT] WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "[INIT] WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"

mkdir -p /shared
cat > /shared/.oauth-credentials << EOF
export WOODPECKER_FORGEJO_CLIENT="$OAUTH_CLIENT_ID"
export WOODPECKER_FORGEJO_SECRET="$OAUTH_CLIENT_SECRET"
EOF
chmod 644 /shared/.oauth-credentials

echo "[INIT] Credentials exportés vers /shared/.oauth-credentials"
echo "[INIT] === first-run-init.sh terminé avec succès ==="
