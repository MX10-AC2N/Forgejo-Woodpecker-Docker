#!/bin/sh

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log /data/gitea/conf /data/git/repositories /backups /shared

chown -R git:git /data /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true
chmod -R 777 /data/log 2>/dev/null || true

# Logging à la fois dans le fichier ET stdout (visible dans docker logs)
log() {
    echo "[ENTRYPOINT] $1" | tee -a "$LOG_FILE"
}

log "$(date '+%Y-%m-%d %H:%M:%S') Démarrage entrypoint custom Forgejo"

# ── Génération app.ini ────────────────────────────────────────────────────
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
    log "app.ini créé : DOMAIN=$DOMAIN, ROOT_URL=$ROOT_URL"
else
    log "app.ini existe déjà, skip"
fi

# ── Créer l'utilisateur admin via CLI ────────────────────────────────────
# Cette commande est exécutée AVANT le démarrage du serveur web.
# Elle écrit directement dans la DB SQLite, pas besoin de serveur actif.
if [ ! -f /data/.admin-created ]; then
    log "Création utilisateur admin via CLI..."
    ADMIN_USER="${ADMIN_USERNAME:-admin}"
    ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
    ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"
    
    # Capturer stdout + stderr pour logger le résultat
    ADMIN_OUTPUT=$(su-exec git /usr/local/bin/forgejo admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASS" \
        --email "$ADMIN_EMAIL" \
        --admin \
        --must-change-password=false \
        --config /data/gitea/conf/app.ini 2>&1) || true
    
    # Logger la sortie complète
    echo "$ADMIN_OUTPUT" | tee -a "$LOG_FILE"
    
    # Vérifier si la création a réussi (ou si l'utilisateur existait déjà)
    if echo "$ADMIN_OUTPUT" | grep -q "successfully created\|already exists"; then
        log "Admin '$ADMIN_USER' prêt (créé ou existe déjà)"
    else
        log "ATTENTION: création admin incertaine, vérifier ci-dessus"
    fi
    
    touch /data/.admin-created
    chown git:git /data/.admin-created
else
    log "Flag .admin-created existe, skip création admin"
fi

# ── Cron en background ────────────────────────────────────────────────────
if command -v crond >/dev/null 2>&1; then
    log "Lancement crond..."
    crond -b 2>/dev/null || log "ERREUR: crond échec"
fi

# ── first-run-init en background ──────────────────────────────────────────
# Lancé comme root pour éviter les problèmes de permissions.
# Il attend 20s que le serveur démarre, puis crée l'OAuth via l'API.
if [ ! -f /data/.initialized ]; then
    touch /data/.initialized
    chown git:git /data/.initialized
    log "Premier démarrage → lancement first-run-init.sh en background"
    
    # Subshell backgroundé, sans set -e, stdout vers docker logs
    ( sleep 20 && /scripts/first-run-init.sh ) &
    
    log "Subshell backgroundé (PID $!)"
else
    log "Flag .initialized existe, skip first-run-init"
fi

# ── Lancement Forgejo (PID 1) ─────────────────────────────────────────────
log "Lancement Forgejo sous user git..."

if [ -x /usr/local/bin/docker-entrypoint.sh ]; then
    exec su-exec git /usr/local/bin/docker-entrypoint.sh "$@"
else
    exec su-exec git /usr/local/bin/forgejo "$@"
fi
