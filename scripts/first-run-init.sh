#!/bin/sh
# Automatisation de la création OAuth via l'interface web Forgejo

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
COOKIE_JAR="/tmp/forgejo-cookies.txt"

echo "[INIT] Admin user : $ADMIN_USER"
echo "[INIT] OAuth redirect : $OAUTH_REDIRECT_URI"

# ── Soumettre le formulaire d'installation ───────────────────────────────
echo "[INIT] Soumission formulaire installation..."

curl -s -X POST http://localhost:3000/ \
  -d "db_type=sqlite3" \
  -d "db_path=/data/gitea/forgejo.db" \
  -d "app_name=Forgejo" \
  -d "repo_root_path=/data/git/repositories" \
  -d "lfs_root_path=/data/gitea/data/lfs" \
  -d "run_user=git" \
  -d "domain=localhost" \
  -d "ssh_port=22" \
  -d "http_port=3000" \
  -d "app_url=http://localhost:5333/" \
  -d "log_root_path=/data/log" \
  -d "admin_name=$ADMIN_USER" \
  -d "admin_passwd=$ADMIN_PASS" \
  -d "admin_confirm_passwd=$ADMIN_PASS" \
  -d "admin_email=$ADMIN_EMAIL" >/dev/null 2>&1

echo "[INIT] Formulaire soumis, attente redémarrage interne..."
sleep 10

# ── Connexion web et récupération session ────────────────────────────────
echo "[INIT] Connexion à l'interface web..."

# GET login page pour récupérer le CSRF
LOGIN_PAGE=$(curl -s -c "$COOKIE_JAR" http://localhost:3000/user/login)
LOGIN_CSRF=$(echo "$LOGIN_PAGE" | grep -o 'name="_csrf" value="[^"]*"' | cut -d'"' -f4)

if [ -z "$LOGIN_CSRF" ]; then
  echo "[INIT] ERREUR: Impossible de récupérer le CSRF token de login"
  exit 1
fi

echo "[INIT] CSRF login récupéré"

# POST login form
curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -X POST http://localhost:3000/user/login \
  -d "_csrf=$LOGIN_CSRF" \
  -d "user_name=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  >/dev/null

echo "[INIT] Connexion effectuée"

# ── Création de l'application OAuth via l'UI web ─────────────────────────
echo "[INIT] Récupération CSRF pour OAuth..."

# GET la page des applications
APPS_PAGE=$(curl -s -b "$COOKIE_JAR" http://localhost:3000/user/settings/applications)
OAUTH_CSRF=$(echo "$APPS_PAGE" | grep -o 'name="_csrf" value="[^"]*"' | cut -d'"' -f4 | head -1)

if [ -z "$OAUTH_CSRF" ]; then
  echo "[INIT] ERREUR: Impossible de récupérer le CSRF token OAuth"
  exit 1
fi

echo "[INIT] CSRF OAuth récupéré"

# POST création OAuth app
echo "[INIT] Création application OAuth..."

OAUTH_RESPONSE=$(curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -X POST http://localhost:3000/user/settings/applications/oauth2 \
  -d "_csrf=$OAUTH_CSRF" \
  -d "application_name=Woodpecker CI" \
  -d "redirect_uri=$OAUTH_REDIRECT_URI" \
  -d "confidential_client=on" \
  -d "skip_secondary_authorization=on")

# ── Extraction des credentials depuis la réponse HTML ────────────────────
echo "[INIT] Extraction des credentials..."

# Forgejo affiche les credentials dans la page de réponse
# Format : Client ID: <code>xxx</code>
#          Client Secret: <code>yyy</code>

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | grep -oP 'Client ID:.*?<code>\K[^<]+' | head -1)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | grep -oP 'Client Secret:.*?<code>\K[^<]+' | head -1)

# Cleanup
rm -f "$COOKIE_JAR"

# ── Validation et output ──────────────────────────────────────────────────
if [ -z "$OAUTH_CLIENT_ID" ] || [ -z "$OAUTH_CLIENT_SECRET" ]; then
  echo "[INIT] ERREUR: Credentials OAuth non trouvés dans la réponse"
  echo "[INIT] Extrait de la réponse HTML :"
  echo "$OAUTH_RESPONSE" | grep -i "client\|error\|already" | head -20
  exit 1
fi

echo "[INIT] OAuth créé avec succès !"
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
echo "[INIT] === first-run-init.sh terminé ==="
