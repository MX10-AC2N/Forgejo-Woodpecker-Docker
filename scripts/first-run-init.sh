#!/bin/sh
# Tout vers stdout → visible dans "docker compose logs forgejo"

echo "[INIT] === Début first-run-init.sh ==="

# ── Attente que l'API réponde ─────────────────────────────────────────────
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
MAX_ATTEMPTS=60

until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "[INIT] ERREUR: Timeout après ${MAX_ATTEMPTS} tentatives"
    exit 1
  fi
  sleep 5
done

echo "[INIT] Forgejo répond !"
sleep 5

# ── Variables ─────────────────────────────────────────────────────────────
# Note : "admin" est réservé dans Forgejo, on utilise "forgejo-admin"
ADMIN_USER="${ADMIN_USERNAME:-forgejo-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"

echo "[INIT] Admin user : $ADMIN_USER"
echo "[INIT] OAuth redirect : $OAUTH_REDIRECT_URI"

# ── Token API via Basic Auth ──────────────────────────────────────────────
# L'utilisateur admin a déjà été créé par entrypoint-cron.sh via CLI.
# On utilise curl (pas wget) car BusyBox wget ne supporte pas --auth-no-challenge.
echo "[INIT] Récupération token admin..."

TOKEN_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
  -H 'Content-Type: application/json' \
  -d '{"name": "init-token-auto"}' \
  http://localhost:3000/api/v1/users/$ADMIN_USER/tokens 2>&1) || true

echo "[INIT] Token response : $TOKEN_RESPONSE"

# Forgejo 14 retourne le token dans .sha1
ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "[INIT] sha1 vide, tentative avec .token..."
  ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token' 2>/dev/null)
fi

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "[INIT] ERREUR: Impossible d'obtenir un token admin"
  echo "[INIT] L'utilisateur '$ADMIN_USER' existe-t-il ?"
  echo "[INIT] Vérifier les logs [ENTRYPOINT] ci-dessus"
  exit 1
fi

echo "[INIT] Token obtenu"

# ── Créer l'application OAuth ─────────────────────────────────────────────
echo "[INIT] Création application OAuth..."

OAUTH_RESPONSE=$(curl -s \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"Woodpecker CI\",\"redirect_uris\":[\"$OAUTH_REDIRECT_URI\"],\"confidential_client\":true,\"scopes\":[\"repo,user:email,read:org,read:repository,write:repository\"]}" \
  http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 2>&1) || true

echo "[INIT] OAuth response : $OAUTH_RESPONSE"

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id' 2>/dev/null)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret' 2>/dev/null)

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ]; then
  echo "[INIT] ERREUR: Échec création OAuth"
  echo "[INIT] Réponse API complète ci-dessus"
  exit 1
fi

# ── Output credentials sur stdout ─────────────────────────────────────────
# Format simple pour grep du workflow CI (sans préfixe [INIT] sur ces lignes)
echo "[INIT] OAuth créé avec succès !"
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
echo "[INIT] === first-run-init.sh terminé ==="
