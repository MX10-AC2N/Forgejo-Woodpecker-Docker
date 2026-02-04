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
ADMIN_USER="${ADMIN_USERNAME:-forgejo-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"

echo "[INIT] Admin user : $ADMIN_USER"
echo "[INIT] OAuth redirect : $OAUTH_REDIRECT_URI"

# ── Vérifier si un admin existe déjà ──────────────────────────────────────
echo "[INIT] Vérification existence admin..."
INSTALL_CHECK=$(curl -s http://localhost:3000/ | grep -o "data-page=\"install\"" || true)

if [ -n "$INSTALL_CHECK" ]; then
    echo "[INIT] Forgejo en mode installation → création admin via formulaire install"
    
    # POST vers /install avec les données du formulaire
    INSTALL_RESPONSE=$(curl -s -X POST http://localhost:3000/ \
      -d "db_type=sqlite3" \
      -d "db_path=/data/gitea/forgejo.db" \
      -d "app_name=Forgejo" \
      -d "repo_root_path=/data/git/repositories" \
      -d "lfs_root_path=/data/gitea/data/lfs" \
      -d "run_user=git" \
      -d "domain=localhost" \
      -d "ssh_port=22" \
      -d "http_port=3000" \
      -d "app_url=$OAUTH_REDIRECT_URI" \
      -d "log_root_path=/data/log" \
      -d "admin_name=$ADMIN_USER" \
      -d "admin_passwd=$ADMIN_PASS" \
      -d "admin_confirm_passwd=$ADMIN_PASS" \
      -d "admin_email=$ADMIN_EMAIL" 2>&1) || true
    
    echo "[INIT] Formulaire install soumis"
    sleep 5
else
    echo "[INIT] Forgejo déjà initialisé, skip formulaire install"
fi

# ── Token API via Basic Auth ──────────────────────────────────────────────
echo "[INIT] Récupération token admin..."

TOKEN_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
  -H 'Content-Type: application/json' \
  -d '{"name": "init-token-auto"}' \
  http://localhost:3000/api/v1/users/$ADMIN_USER/tokens 2>&1) || true

echo "[INIT] Token response : $TOKEN_RESPONSE"

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token' 2>/dev/null)
fi

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "[INIT] ERREUR: Impossible d'obtenir un token admin"
  echo "[INIT] L'utilisateur '$ADMIN_USER' existe-t-il ?"
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
  exit 1
fi

# ── Output credentials ────────────────────────────────────────────────────
echo "[INIT] OAuth créé avec succès !"
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
echo "[INIT] === first-run-init.sh terminé ==="
