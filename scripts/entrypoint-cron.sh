#!/bin/sh
set -e

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log /data/gitea/conf
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes
mkdir -p /data/git/repositories /data/log /backups /shared
chown -R git:git /data /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true

# Copier app.ini par défaut si absent
if [ ! -f /data/gitea/conf/app.ini ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Création app.ini par défaut..." >> "$LOG_FILE"
    cat > /data/gitea/conf/app.ini << 'APPINI'
[database]
DB_TYPE = sqlite3
PATH    = /data/gitea/forgejo.db

[repository]
ROOT = /data/git/repositories

[server]
DOMAIN           = ${FORGEJO_DOMAIN:-localhost}
HTTP_PORT        = 3000
ROOT_URL         = ${FORGEJO_ROOT_URL:-http://localhost:3000/}
DISABLE_SSH      = false
SSH_PORT         = ${FORGEJO_SSH_PORT:-22}
LFS_START_SERVER = true

[log]
MODE      = console
LEVEL     = Info
ROOT_PATH = /data/log

[security]
INSTALL_LOCK   = true
SECRET_KEY     = $(openssl rand -hex 32)
INTERNAL_TOKEN = $(openssl rand -hex 50)

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
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Lancer cron en background
if command -v crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond..." >> "$LOG_FILE"
    crond -b 2>/dev/null || echo "⚠️ crond échec" >> "$LOG_FILE"
fi

# Lancer first-run-init en background
if [ ! -f /data/.initialized ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Premier démarrage → init en background" >> "$LOG_FILE"
    touch /data/.initialized
    
    (
        sleep 20
        su-exec git /scripts/first-run-init.sh >> "$LOG_FILE" 2>&1 || echo "⚠️ Init failed" >> "$LOG_FILE"
    ) &
fi

# Lancer Forgejo en tant que user git
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement Forgejo sous user git..." >> "$LOG_FILE"

if [ -x /usr/local/bin/docker-entrypoint.sh ]; then
    exec su-exec git /usr/local/bin/docker-entrypoint.sh "$@"
else
    exec su-exec git /usr/local/bin/forgejo "$@"
fi