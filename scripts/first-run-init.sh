#!/bin/sh
# Pas de set -e : on veut voir les erreurs dans docker logs, pas crasher en silence

echo "[INIT] === Début first-run-init.sh ==="

# ── Attente que l'API réponde ────────────────────────────────────────────
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
MAX_ATTEMPTS=60

until curl --silent --fail --max-time 5 http://localhost:3000/api/healthz >/dev/null 2>&1; do
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
echo "[INIT] Récupération token admin..."

TOKEN_RESPONSE=$(curl --silent --fail-with-body \
  -u "\( {ADMIN_USER}: \){ADMIN_PASS}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "woodpecker-init-token"}' \
  "http://localhost:3000/api/v1/users/${ADMIN_USER}/tokens" 2>&1)

if [ $? -ne 0 ]; then
  echo "[INIT] ERREUR lors de la création du token admin (code curl $?)"
  echo "[INIT] Réponse complète :"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "[INIT] Token response : $TOKEN_RESPONSE"

# Forgejo retourne généralement .sha1, parfois .token selon les versions
ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1 // .token // "null"' 2>/dev/null)

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo "[INIT] ERREUR: Impossible d'obtenir un token admin (champ sha1/token absent ou null)"
  echo "[INIT] Response complète : $TOKEN_RESPONSE"
  exit 1
fi

echo "[INIT] Token obtenu : ${ADMIN_TOKEN:0:16}..."

# ── Créer l'application OAuth pour Woodpecker ────────────────────────────
echo "[INIT] Création application OAuth..."

OAUTH_RESPONSE=$(curl --silent --fail-with-body \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Woodpecker CI\",\"redirect_uris\":[\"${OAUTH_REDIRECT_URI}\"],\"confidential_client\":true,\"scopes\":[\"repo\",\"user:email\",\"read:org\",\"read:repository\",\"write:repository\"]}" \
  "http://localhost:3000/api/v1/users/${ADMIN_USER}/applications/oauth2" 2>&1)

if [ $? -ne 0 ]; then
  echo "[INIT] ERREUR lors de la création de l'application OAuth (code curl $?)"
  echo "[INIT] Réponse complète :"
  echo "$OAUTH_RESPONSE"
  exit 1
fi

echo "[INIT] OAuth response : $OAUTH_RESPONSE"

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id // "null"' 2>/dev/null)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret // "null"' 2>/dev/null)

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ] || \
   [ "$OAUTH_CLIENT_SECRET" = "null" ] || [ -z "$OAUTH_CLIENT_SECRET" ]; then
  echo "[INIT] ERREUR: Échec création OAuth - client_id ou client_secret manquant"
  echo "[INIT] Response complète : $OAUTH_RESPONSE"
  exit 1
fi

# ── Export vers volume partagé ────────────────────────────────────────────
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