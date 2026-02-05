#!/bin/sh

# -------------------------------------------------------------------------
# first‑run‑init.sh – automatisation OAuth via scraping web
# Compatible BusyBox/Alpine
# -------------------------------------------------------------------------

echo "[INIT] === Début first-run-init.sh ==="

# ── Attente que Forgejo soit prêt ────────────────────────────────────────
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  [ $ATTEMPT -ge 60 ] && echo "[INIT] ERREUR: Timeout" && exit 1
  sleep 5
done
echo "[INIT] Forgejo répond !"

# ── Variables ───────────────────────────────────────────────────────────
ADMIN_USER="${ADMIN_USERNAME:-forgejo-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"

# Utiliser l'URL interne de Woodpecker (résolue via Docker DNS)
WOODPECKER_INTERNAL_URL="${WOODPECKER_INTERNAL_URL:-${WOODPECKER_HOST:-http://localhost:5444}}"
OAUTH_REDIRECT_URI="${WOODPECKER_INTERNAL_URL}/authorize"

COOKIE_JAR="/data/tmp/forgejo-cookies.txt"
mkdir -p "$(dirname "$COOKIE_JAR")" && chown git:git "$(dirname "$COOKIE_JAR")"

echo "[INIT] Admin: $ADMIN_USER | Redirect: $OAUTH_REDIRECT_URI"

# ── Installation du formulaire Forgejo ─────────────────────────────────
echo "[INIT] Soumission formulaire installation..."
curl -s -X POST http://localhost:3000/ \
  -d "db_type=sqlite3" -d "db_path=/data/gitea/forgejo.db" \
  -d "app_name=Forgejo" -d "repo_root_path=/data/git/repositories" \
  -d "lfs_root_path=/data/gitea/data/lfs" -d "run_user=git" \
  -d "domain=localhost" -d "ssh_port=22" -d "http_port=3000" \
  -d "app_url=http://localhost:5333/" -d "log_root_path=/data/log" \
  -d "admin_name=$ADMIN_USER" -d "admin_passwd=$ADMIN_PASS" \
  -d "admin_confirm_passwd=$ADMIN_PASS" -d "admin_email=$ADMIN_EMAIL" \
  >/dev/null 2>&1

echo "[INIT] Formulaire soumis, attente du redémarrage du serveur web..."
# Le serveur redémarre après l'installation – on attend qu'il revienne OK.
for i in $(seq 1 30); do
  if wget --quiet --spider http://localhost:3000/api/healthz 2>/dev/null; then
    echo "[INIT] Serveur de nouveau opérationnel"
    break
  fi
  sleep 2
done

# ── Connexion web ───────────────────────────────────────────────────────
echo "[INIT] Connexion interface web..."
LOGIN_PAGE=$(curl -s -c "$COOKIE_JAR" http://localhost:3000/user/login)

# Extraction robuste du token CSRF (acceptes les deux ordres d'attributs)
LOGIN_CSRF=$(echo "$LOGIN_PAGE" | grep -oP '(?<=name="_csrf".*value=")[^"]+')
if [ -z "$LOGIN_CSRF" ]; then
  LOGIN_CSRF=$(echo "$LOGIN_PAGE" | grep -oP '(?<=value=")[^"]+(?=".*name="_csrf")')
fi

if [ -z "$LOGIN_CSRF" ]; then
  echo "[INIT] ERREUR: CSRF login introuvable"
  echo "[INIT] Debug HTML (login page) sauvegardée dans /data/log/login_page_debug.html"
  echo "$LOGIN_PAGE" > /data/log/login_page_debug.html
  exit 1
fi

echo "[INIT] CSRF login OK (${#LOGIN_CSRF} chars)"

# POST login
curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST http://localhost:3000/user/login \
  -d "_csrf=$LOGIN_CSRF" -d "user_name=$ADMIN_USER" -d "password=$ADMIN_PASS" \
  >/dev/null

echo "[INIT] Login POST soumis"

#