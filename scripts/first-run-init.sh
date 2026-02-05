#!/bin/sh
# Automatisation OAuth via scraping web - compatible BusyBox/Alpine

echo "[INIT] === Début first-run-init.sh ==="

# ── Attente Forgejo ───────────────────────────────────────────────────────
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  [ $ATTEMPT -ge 60 ] && echo "[INIT] ERREUR: Timeout" && exit 1
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

echo "[INIT] Admin: $ADMIN_USER | Redirect: $OAUTH_REDIRECT_URI"

# ── Installation ──────────────────────────────────────────────────────────
echo "[INIT] Soumission formulaire installation..."
curl -s -X POST http://localhost:3000/ \
  -d "db_type=sqlite3" -d "db_path=/data/gitea/forgejo.db" \
  -d "app_name=Forgejo" -d "repo_root_path=/data/git/repositories" \
  -d "lfs_root_path=/data/gitea/data/lfs" -d "run_user=git" \
  -d "domain=localhost" -d "ssh_port=22" -d "http_port=3000" \
  -d "app_url=http://localhost:5333/" -d "log_root_path=/data/log" \
  -d "admin_name=$ADMIN_USER" -d "admin_passwd=$ADMIN_PASS" \
  -d "admin_confirm_passwd=$ADMIN_PASS" -d "admin_email=$ADMIN_EMAIL" >/dev/null 2>&1
echo "[INIT] Formulaire soumis, sleep 10s..."
sleep 10

# ── Connexion web ─────────────────────────────────────────────────────────
echo "[INIT] Connexion interface web..."
LOGIN_PAGE=$(curl -s -c "$COOKIE_JAR" http://localhost:3000/user/login)

# Extraction CSRF avec sed (compatible BusyBox)
LOGIN_CSRF=$(echo "$LOGIN_PAGE" | sed -n 's/.*name="_csrf"[^>]*value="\([^"]*\)".*/\1/p' | head -1)
if [ -z "$LOGIN_CSRF" ]; then
  LOGIN_CSRF=$(echo "$LOGIN_PAGE" | sed -n 's/.*value="\([^"]*\)"[^>]*name="_csrf".*/\1/p' | head -1)
fi

if [ -z "$LOGIN_CSRF" ]; then
  echo "[INIT] ERREUR: CSRF login introuvable"
  echo "[INIT] Debug HTML (lignes avec csrf/input) :"
  echo "$LOGIN_PAGE" | grep -i "csrf\|<input" | head -10
  exit 1
fi

echo "[INIT] CSRF login OK (${#LOGIN_CSRF} chars)"

# POST login
curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST http://localhost:3000/user/login \
  -d "_csrf=$LOGIN_CSRF" -d "user_name=$ADMIN_USER" -d "password=$ADMIN_PASS" >/dev/null
echo "[INIT] Login POST soumis"

# ── Création OAuth ────────────────────────────────────────────────────────
echo "[INIT] Récupération CSRF OAuth..."
APPS_PAGE=$(curl -s -b "$COOKIE_JAR" http://localhost:3000/user/settings/applications)

OAUTH_CSRF=$(echo "$APPS_PAGE" | sed -n 's/.*name="_csrf"[^>]*value="\([^"]*\)".*/\1/p' | head -1)
if [ -z "$OAUTH_CSRF" ]; then
  OAUTH_CSRF=$(echo "$APPS_PAGE" | sed -n 's/.*value="\([^"]*\)"[^>]*name="_csrf".*/\1/p' | head -1)
fi

if [ -z "$OAUTH_CSRF" ]; then
  echo "[INIT] ERREUR: CSRF OAuth introuvable"
  echo "$APPS_PAGE" | grep -i "csrf\|<input" | head -10
  exit 1
fi

echo "[INIT] CSRF OAuth OK (${#OAUTH_CSRF} chars)"

# POST création OAuth
echo "[INIT] POST création OAuth app..."
OAUTH_RESPONSE=$(curl -s -b "$COOKIE_JAR" -X POST \
  http://localhost:3000/user/settings/applications/oauth2 \
  -d "_csrf=$OAUTH_CSRF" \
  -d "application_name=Woodpecker CI" \
  -d "redirect_uri=$OAUTH_REDIRECT_URI" \
  -d "confidential_client=on" \
  -d "skip_secondary_authorization=on")

# ── Extraction credentials avec sed ───────────────────────────────────────
echo "[INIT] Extraction credentials..."

# Format : Client ID: <code>xxx</code>
OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | sed -n 's/.*Client ID[^<]*<code>\([^<]*\)<\/code>.*/\1/p' | head -1)
if [ -z "$OAUTH_CLIENT_ID" ]; then
  # Fallback sans <code>
  OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | sed -n 's/.*Client ID[: ]*\([a-f0-9-]\{20,\}\).*/\1/p' | head -1)
fi

OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | sed -n 's/.*Client Secret[^<]*<code>\([^<]*\)<\/code>.*/\1/p' | head -1)
if [ -z "$OAUTH_CLIENT_SECRET" ]; then
  OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | sed -n 's/.*Client Secret[: ]*\([a-f0-9-]\{20,\}\).*/\1/p' | head -1)
fi

rm -f "$COOKIE_JAR"

if [ -z "$OAUTH_CLIENT_ID" ] || [ -z "$OAUTH_CLIENT_SECRET" ]; then
  echo "[INIT] ERREUR: Credentials non extraits"
  echo "[INIT] Debug réponse (lignes avec client/secret) :"
  echo "$OAUTH_RESPONSE" | grep -i "client\|secret" | head -15
  exit 1
fi

echo "[INIT] OAuth créé avec succès !"
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
echo "[INIT] === first-run-init.sh terminé ==="
