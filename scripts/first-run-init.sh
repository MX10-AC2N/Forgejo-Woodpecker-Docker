#!/bin/sh
# Pas de set -e : on veut voir les erreurs dans les logs

echo "[INIT] === Début first-run-init.sh ==="

# ── Attente que Forgejo soit prêt (healthz OK) ──────────────────────────
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
MAX_ATTEMPTS=60

until curl --silent --fail --max-time 5 http://localhost:3000/api/healthz >/dev/null 2>&1; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "[INIT] ERREUR: Timeout après ${MAX_ATTEMPTS} tentatives"
    exit 1
  fi
  echo "[INIT] Pas prêt... (tentative $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 5
done

echo "[INIT] Forgejo répond !"
sleep 5  # Marge pour init DB complète si besoin

# ── Variables ────────────────────────────────────────────────────────────
ADMIN_USER="${ADMIN_USERNAME:-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"  # Ajoute ADMIN_EMAIL dans docker-compose si différent
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"

echo "[INIT] Admin user : $ADMIN_USER"
echo "[INIT] OAuth redirect : $OAUTH_REDIRECT_URI"

# ── Créer l'utilisateur admin via CLI (si inexistant) ───────────────────
echo "[INIT] Création / vérification admin via CLI..."

CREATE_OUTPUT=$(su - git -c "forgejo admin user create \
  --username '${ADMIN_USER}' \
  --password '${ADMIN_PASS}' \
  --email '${ADMIN_EMAIL}' \
  --admin \
  --must-change-password false" 2>&1)

if echo "$CREATE_OUTPUT" | grep -iq "already exists"; then
  echo "[INIT] Utilisateur $ADMIN_USER existe déjà."
elif [ $? -ne 0 ]; then
  echo "[INIT] ERREUR création utilisateur:"
  echo "$CREATE_OUTPUT"
  exit 1
else
  echo "[INIT] Admin créé avec succès."
fi

# ── Générer token API via CLI ───────────────────────────────────────────
echo "[INIT] Génération token admin via CLI..."

ADMIN_TOKEN=$(su - git -c "forgejo admin user generate-access-token \
  --username '${ADMIN_USER}' \
  --token-name 'woodpecker-init-token' \
  --scopes 'all' \
  --raw" 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "[INIT] ERREUR: Échec génération token CLI"
  echo "Vérifie la commande: docker compose exec forgejo su - git -c 'forgejo admin user generate-access-token --help'"
  exit 1
fi

echo "[INIT] Token obtenu : ${ADMIN_TOKEN:0:16}..."

# ── Créer application OAuth via API ─────────────────────────────────────
echo "[INIT] Création application OAuth..."

OAUTH_RESPONSE=$(curl --silent --fail-with-body \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Woodpecker CI\",\"redirect_uris\":[\"${OAUTH_REDIRECT_URI}\"],\"confidential_client\":true,\"scopes\":[\"repo\",\"user:email\",\"read:org\",\"read:repository\",\"write:repository\"]}" \
  "http://localhost:3000/api/v1/users/${ADMIN_USER}/applications/oauth2" 2>&1)

if [ $? -ne 0 ]; then
  echo "[INIT] ERREUR création OAuth (curl $?)"
  echo "$OAUTH_RESPONSE"
  exit 1
fi

echo "[INIT] OAuth response : $OAUTH_RESPONSE"

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id // "null"')
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret // "null"')

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ] || \
   [ "$OAUTH_CLIENT_SECRET" = "null" ] || [ -z "$OAUTH_CLIENT_SECRET" ]; then
  echo "[INIT] ERREUR: client_id ou secret manquant"
  echo "$OAUTH_RESPONSE"
  exit 1
fi

# ── Export vers volume partagé ──────────────────────────────────────────
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