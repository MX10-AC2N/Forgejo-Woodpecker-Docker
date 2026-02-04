#!/bin/sh

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log /data/gitea/conf /data/git/repositories /backups /shared

chown -R git:git /data /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true
chmod -R 777 /data/log 2>/dev/null || true

log() {
    echo "[ENTRYPOINT] $1" | tee -a "$LOG_FILE"
}

log "$(date '+%Y-%m-%d %H:%M:%S') Démarrage entrypoint custom Forgejo"

# ── Génération app.ini ────────────────────────────────────────────────────
# NOTE IMPORTANTE : on ne met PAS INSTALL_LOCK=true ici.
# On laisse Forgejo gérer son premier démarrage proprement.
if [ ! -f /data/gitea/conf/app.ini ]; then
    log "Création app.ini par défaut..."
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
    log "app.ini créé : DOMAIN=$DOMAIN, ROOT_URL=$ROOT_URL (sans INSTALL_LOCK)"
else
    log "app.ini existe déjà, skip"
fi

# ── Cron en background ────────────────────────────────────────────────────
if command -v crond >/dev/null 2>&1; then
    log "Lancement crond..."
    crond -b 2>/dev/null || log "WARNING: crond échec"
fi

# ── first-run-init en background ──────────────────────────────────────────
if [ ! -f /data/.initialized ]; then
    touch /data/.initialized
    chown git:git /data/.initialized
    log "Premier démarrage → lancement first-run-init.sh en background"
    
    ( sleep 30 && /scripts/first-run-init.sh ) &
    
    log "Subshell backgroundé (PID $!)"
else
    log "Flag .initialized existe, skip first-run-init"
fi

# ── Lancement Forgejo (PID 1) ─────────────────────────────────────────────
log "Lancement Forgejo sous user git..."

# Forgejo va détecter qu'il n'y a pas d'admin et créer le premier user
# via les variables d'environnement ou via l'API au premier démarrage.
if [ -x /usr/local/bin/docker-entrypoint.sh ]; then
    exec su-exec git /usr/local/bin/docker-entrypoint.sh "$@"
else
    exec su-exec git /usr/local/bin/forgejo "$@"
fi
