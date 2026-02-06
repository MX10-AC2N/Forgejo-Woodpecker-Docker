#!/bin/sh
# -------------------------------------------------------------------------
# first-run-init.sh – Automatisation OAuth Forgejo→Woodpecker
# Version CORRIGÉE - 100% compatible BusyBox/Alpine
# -------------------------------------------------------------------------

set -e  # Arrêt immédiat en cas d'erreur

echo "[INIT] === Début first-run-init.sh ==="

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 1 : Attente que Forgejo soit prêt
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge 60 ]; then
    echo "[INIT] ERREUR: Timeout - Forgejo ne répond pas après 5 minutes"
    exit 1
  fi
  sleep 5
done
echo "[INIT] ✓ Forgejo répond!"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 2 : Variables d'environnement
# ══════════════════════════════════════════════════════════════════════════
ADMIN_USER="${ADMIN_USERNAME:-forgejo-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"

# URL interne de Woodpecker (résolue via Docker DNS)
WOODPECKER_INTERNAL_URL="${WOODPECKER_INTERNAL_URL:-${WOODPECKER_HOST:-http://woodpecker-server:8000}}"
OAUTH_REDIRECT_URI="${WOODPECKER_INTERNAL_URL}/authorize"

COOKIE_JAR="/data/tmp/forgejo-cookies.txt"
mkdir -p "$(dirname "$COOKIE_JAR")" && chown git:git "$(dirname "$COOKIE_JAR")"

echo "[INIT] Configuration:"
echo "[INIT]   Admin: $ADMIN_USER"
echo "[INIT]   Redirect URI: $OAUTH_REDIRECT_URI"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 3 : Installation de Forgejo (si nécessaire)
# ══════════════════════════════════════════════════════════════════════════
if [ -f /data/gitea/forgejo.db ]; then
  echo "[INIT] ⚠ Forgejo déjà installé (forgejo.db existe), passage à l'étape suivante"
else
  echo "[INIT] Installation de Forgejo via formulaire web..."
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
    -d "admin_email=$ADMIN_EMAIL" \
    >/dev/null 2>&1

  echo "[INIT] Formulaire soumis, attente du redémarrage du serveur..."
  # Le serveur redémarre après l'installation
  sleep 5
  ATTEMPT=0
  until wget --quiet --spider http://localhost:3000/api/healthz 2>/dev/null; do
    ATTEMPT=$((ATTEMPT + 1))
    [ $ATTEMPT -ge 30 ] && echo "[INIT] ERREUR: Timeout au redémarrage" && exit 1
    sleep 2
  done
  echo "[INIT] ✓ Serveur redémarré avec succès"
fi

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 4 : Connexion à l'interface web
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Connexion à l'interface web..."
LOGIN_PAGE=$(curl -s -c "$COOKIE_JAR" http://localhost:3000/user/login)

# Extraction du token CSRF avec plusieurs stratégies de fallback
# Stratégie 1: <input type="hidden" name="_csrf" value="xxx">
LOGIN_CSRF=$(echo "$LOGIN_PAGE" | sed -n 's/.*name="_csrf"[^>]*value="\([^"]*\)".*/\1/p' | head -n1)

# Stratégie 2: ordre inverse value="xxx" ... name="_csrf"
if [ -z "$LOGIN_CSRF" ]; then
  LOGIN_CSRF=$(echo "$LOGIN_PAGE" | sed -n 's/.*value="\([^"]*\)"[^>]*name="_csrf".*/\1/p' | head -n1)
fi

# Stratégie 3: extraction avec awk (plus robuste)
if [ -z "$LOGIN_CSRF" ]; then
  LOGIN_CSRF=$(echo "$LOGIN_PAGE" | awk -F'"' '/_csrf/ && /value=/ {for(i=1;i<=NF;i++) if($(i-1)~"value=") print $i}' | head -n1)
fi

# Stratégie 4: extraction via grep simple (BusyBox compatible)
if [ -z "$LOGIN_CSRF" ]; then
  LOGIN_CSRF=$(echo "$LOGIN_PAGE" | grep '_csrf' | sed 's/.*value="\([^"]*\)".*/\1/' | head -n1)
fi

if [ -z "$LOGIN_CSRF" ]; then
  echo "[INIT] ❌ ERREUR: Token CSRF login introuvable"
  echo "[INIT] Debug: page de login sauvegardée dans /data/log/login_page_debug.html"
  echo "$LOGIN_PAGE" > /data/log/login_page_debug.html
  exit 1
fi

echo "[INIT] ✓ Token CSRF récupéré (${#LOGIN_CSRF} caractères)"

# Soumission du formulaire de login
LOGIN_RESPONSE=$(curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -X POST http://localhost:3000/user/login \
  -d "_csrf=$LOGIN_CSRF" \
  -d "user_name=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
echo "[INIT] ✓ Login soumis (HTTP $HTTP_CODE)"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 5 : Création de l'application OAuth
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Accès à la page de création d'application OAuth..."
OAUTH_PAGE=$(curl -s -b "$COOKIE_JAR" http://localhost:3000/user/settings/applications)

# Extraction du token CSRF pour OAuth avec fallback strategies
OAUTH_CSRF=$(echo "$OAUTH_PAGE" | sed -n 's/.*name="_csrf"[^>]*value="\([^"]*\)".*/\1/p' | head -n1)

if [ -z "$OAUTH_CSRF" ]; then
  OAUTH_CSRF=$(echo "$OAUTH_PAGE" | sed -n 's/.*value="\([^"]*\)"[^>]*name="_csrf".*/\1/p' | head -n1)
fi

if [ -z "$OAUTH_CSRF" ]; then
  OAUTH_CSRF=$(echo "$OAUTH_PAGE" | awk -F'"' '/_csrf/ && /value=/ {for(i=1;i<=NF;i++) if($(i-1)~"value=") print $i}' | head -n1)
fi

if [ -z "$OAUTH_CSRF" ]; then
  OAUTH_CSRF=$(echo "$OAUTH_PAGE" | grep '_csrf' | sed 's/.*value="\([^"]*\)".*/\1/' | head -n1)
fi

if [ -z "$OAUTH_CSRF" ]; then
  echo "[INIT] ❌ ERREUR: Token CSRF OAuth introuvable"
  echo "[INIT] Debug: page OAuth sauvegardée dans /data/log/oauth_page_debug.html"
  echo "$OAUTH_PAGE" > /data/log/oauth_page_debug.html
  exit 1
fi

echo "[INIT] ✓ Token CSRF OAuth récupéré"

# Création de l'application OAuth
echo "[INIT] Création de l'application OAuth 'Woodpecker CI'..."
OAUTH_CREATE_RESPONSE=$(curl -s -b "$COOKIE_JAR" \
  -X POST http://localhost:3000/user/settings/applications \
  -d "_csrf=$OAUTH_CSRF" \
  -d "application_name=Woodpecker CI" \
  -d "redirect_uri=$OAUTH_REDIRECT_URI" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$OAUTH_CREATE_RESPONSE" | tail -n1)
OAUTH_RESULT=$(echo "$OAUTH_CREATE_RESPONSE" | sed '$d')

echo "[INIT] ✓ Application OAuth créée (HTTP $HTTP_CODE)"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 6 : Extraction des credentials OAuth
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Extraction des credentials OAuth..."

# Récupération de la page des applications pour obtenir les credentials
APPS_PAGE=$(curl -s -b "$COOKIE_JAR" http://localhost:3000/user/settings/applications)

# Extraction du Client ID avec plusieurs stratégies BusyBox-compatible
# Stratégie 1: Pattern HTML standard
CLIENT_ID=$(echo "$APPS_PAGE" | sed -n 's/.*<dt>Client ID<\/dt>[[:space:]]*<dd><code>\([^<]*\)<\/code>.*/\1/p' | head -n1)

# Stratégie 2: Extraction plus permissive
if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(echo "$APPS_PAGE" | grep -A 3 'Client ID' | grep '<code>' | sed 's/.*<code>\([^<]*\)<\/code>.*/\1/' | head -n1)
fi

# Stratégie 3: Pattern UUID général (sans regex avancée)
if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(echo "$APPS_PAGE" | tr ' ' '\n' | grep '^[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}$' | head -n1)
fi

# Extraction du Client Secret avec plusieurs stratégies
# Stratégie 1: Pattern HTML standard
CLIENT_SECRET=$(echo "$APPS_PAGE" | sed -n 's/.*<dt>Client Secret<\/dt>[[:space:]]*<dd><code>\([^<]*\)<\/code>.*/\1/p' | head -n1)

# Stratégie 2: Extraction plus permissive
if [ -z "$CLIENT_SECRET" ]; then
  CLIENT_SECRET=$(echo "$APPS_PAGE" | grep -A 3 'Client Secret' | grep '<code>' | sed 's/.*<code>\([^<]*\)<\/code>.*/\1/' | head -n1)
fi

# Stratégie 3: Pattern alphanumérique long (typique des secrets OAuth)
if [ -z "$CLIENT_SECRET" ]; then
  # Recherche d'une séquence de 32+ caractères alphanumériques (potentiellement avec - ou _)
  CLIENT_SECRET=$(echo "$APPS_PAGE" | tr ' ' '\n' | grep '^[a-zA-Z0-9_-]\{32,\}$' | head -n1)
fi

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "[INIT] ⚠ Impossible d'extraire automatiquement les credentials"
  echo "[INIT] Debug: page applications sauvegardée dans /data/log/apps_page_debug.html"
  echo "$APPS_PAGE" > /data/log/apps_page_debug.html
  
  # Tentative ultime: extraire via jq si la page contient du JSON
  if command -v jq >/dev/null 2>&1; then
    echo "[INIT] Tentative avec jq..."
    CLIENT_ID=$(echo "$APPS_PAGE" | jq -r '.client_id // empty' 2>/dev/null | head -n1)
    CLIENT_SECRET=$(echo "$APPS_PAGE" | jq -r '.client_secret // empty' 2>/dev/null | head -n1)
  fi
fi

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "[INIT] ❌ ERREUR: Impossible de récupérer les credentials OAuth"
  echo "[INIT] Configuration manuelle nécessaire (voir /data/log/apps_page_debug.html)"
  exit 1
fi

echo "[INIT] ✓ Credentials OAuth récupérés!"
echo "[INIT]   Client ID: $CLIENT_ID"
echo "[INIT]   Client Secret: ${CLIENT_SECRET:0:8}..."

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 7 : Sauvegarde des credentials dans le volume partagé
# ══════════════════════════════════════════════════════════════════════════
SHARED_OAUTH_FILE="/shared/oauth-credentials.env"

echo "[INIT] Écriture des credentials dans $SHARED_OAUTH_FILE..."
cat > "$SHARED_OAUTH_FILE" << EOF
# OAuth credentials générés automatiquement
# Date: $(date -Iseconds)
WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID
WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET
EOF

chmod 644 "$SHARED_OAUTH_FILE"
chown git:git "$SHARED_OAUTH_FILE"

echo "[INIT] ✓ Credentials sauvegardés dans le volume partagé"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 8 : Affichage des credentials dans les logs (pour extraction)
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          CREDENTIALS OAUTH GÉNÉRÉS AVEC SUCCÈS                 ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║ WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID"
echo "║ WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Credentials pour extraction automatique par GitHub Actions
# (doit être au début de ligne pour le grep du workflow)
echo "WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET"

# Signal de fin pour les tests automatisés
echo "[INIT] ✅ Configuration OAuth terminée avec succès!"
echo "[INIT] first-run-init.sh terminé"

exit 0
