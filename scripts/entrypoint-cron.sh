#!/bin/sh
# set -e volontairement ABSENT : on ne veut pas que le conteneur crashe
# sur une erreur non-fatale (chown, crond, etc.)

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log /data/gitea/conf /data/git/repositories /backups /shared

# ── Permissions globales (on est root à ce stade) ────────────────────────
chown -R git:git /data /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true
# ./logs est monté depuis l'hôte par le runner (uid runner) →
# on force la permission pour que git puisse écrire dedans
chmod -R 777 /data/log 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# ── Génération app.ini (premier démarrage uniquement) ────────────────────
if [ ! -f /data/gitea/conf/app.ini ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Création app.ini par défaut..." >> "$LOG_FILE"

    DOMAIN="${FORGEJO_DOMAIN:-localhost}"
    ROOT_URL="${FORGEJO_ROOT_URL:-http://localhost:3000/}"
    SSH_PORT_CONF="${FORGEJO_SSH_PORT:-22}"

    SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 64)
    INTERNAL_TOKEN=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 100)

    cat > /data/gitea/conf/app.ini << APPINI
[database]
DB_TYPE = sqlite3
PATH    = /data/gitea/forgejo.db

[repository]
ROOT = /data/git/repositories

[server]
DOMAIN           = ${DOMAIN}
HTTP_PORT        = 3000
ROOT_URL         = ${ROOT_URL}
DISABLE_SSH      = false
SSH_PORT         = ${SSH_PORT_CONF}
LFS_START_SERVER = true

[log]
MODE      = console
LEVEL     = Info
ROOT_PATH = /data/log

[security]
INSTALL_LOCK   = true
SECRET_KEY     = ${SECRET_KEY}
INTERNAL_TOKEN = ${INTERNAL_TOKEN}

[service]
DISABLE_REGISTRATION       = false
REQUIRE_SIGNIN_VIEW        = false
DEFAULT_KEEP_EMAIL_PRIVATE = false
NO_REPLY_ADDRESS           = noreply.localhost

[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false

[session]
PROVIDER = file
APPINI

    chown git:git /data/gitea/conf/app.ini
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] app.ini créé avec DOMAIN=$DOMAIN, ROOT_URL=$ROOT_URL" >> "$LOG_FILE"
fi

# ── Créer l'utilisateur admin via CLI AVANT le serveur ───────────────────
# API /admin/users → 401 sans token. La CLI écrit directement en DB.
if [ ! -f /data/.admin-created ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Création utilisateur admin via CLI..." >> "$LOG_FILE"

    ADMIN_USER="${ADMIN_USERNAME:-admin}"
    ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
    ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"

    su-exec git /usr/local/bin/forgejo admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASS" \
        --email "$ADMIN_EMAIL" \
        --admin \
        --must-change-password=false \
        --config /data/gitea/conf/app.ini >> "$LOG_FILE" 2>&1 || true

    touch /data/.admin-created
    chown git:git /data/.admin-created
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Admin '$ADMIN_USER' créé via CLI" >> "$LOG_FILE"
fi

# ── Cron en background ────────────────────────────────────────────────────
if command -v crond >/dev/null 2>&1; then
    crond -b 2>/dev/null || true
fi

# ── first-run-init en background ──────────────────────────────────────────
# Lancé comme root pour éviter les problèmes de permissions sur les volumes.
# Le script lui-même ne fait que des requêtes HTTP + écriture dans /shared.
if [ ! -f /data/.initialized ]; then
    touch /data/.initialized
    chown git:git /data/.initialized
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Premier démarrage → init OAuth en background" >> "$LOG_FILE"

    # Subshell backgroundé, sans set -e, stdout vers docker logs
    ( sleep 20 && /scripts/first-run-init.sh ) &
fi

# ── Lancement Forgejo (PID 1) ─────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement Forgejo sous user git..." >> "$LOG_FILE"

if [ -x /usr/local/bin/docker-entrypoint.sh ]; then
    exec su-exec git /usr/local/bin/docker-entrypoint.sh "$@"
else
    exec su-exec git /usr/local/bin/forgejo "$@"
fi
