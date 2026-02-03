#!/bin/sh
set -e

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log /data/gitea/conf
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes
mkdir -p /data/git/repositories /data/log /backups /shared
chown -R git:git /data /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true

# Permettre la création de l'admin par API
export INSTALL_LOCK=false

# Copier app.ini par défaut si absent
if [ ! -f /data/gitea/conf/app.ini ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Création app.ini par défaut..." >> "$LOG_FILE"

    # Récupérer les variables d'environnement avec valeurs par défaut
    DOMAIN="${FORGEJO_DOMAIN:-localhost}"
    ROOT_URL="${FORGEJO_ROOT_URL:-http://localhost:3000/}"
    SSH_PORT_CONF="${FORGEJO_SSH_PORT:-22}"

    # Générer les secrets (pas openssl dans cette image Alpine)
    SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 64)
    INTERNAL_TOKEN=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 100)

    # Créer app.ini avec substitution de variables
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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Lancer cron en background
if command -v crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond..." >> "$LOG_FILE"
    crond -b 2>/dev/null || echo "crond échec" >> "$LOG_FILE"
fi

# Lancer first-run-init en background
if [ ! -f /data/.initialized ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Premier démarrage → init en background" >> "$LOG_FILE"
    touch /data/.initialized

    (
        sleep 20
        su-exec git /scripts/first-run-init.sh >> "$LOG_FILE" 2>&1 || echo "Init failed" >> "$LOG_FILE"
    ) &
fi

# Lancer Forgejo en tant que user git
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement Forgejo sous user git..." >> "$LOG_FILE"

if [ -x /usr/local/bin/docker-entrypoint.sh ]; then
    exec su-exec git /usr/local/bin/docker-entrypoint.sh "$@"
else
    exec su-exec git /usr/local/bin/forgejo "$@"
fi