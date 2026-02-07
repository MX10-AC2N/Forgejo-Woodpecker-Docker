#!/bin/sh
# -------------------------------------------------------------------------
# first-run-init.sh – OAuth via API Forgejo
# Version CORRIGÉE - Utilise uniquement l'API, pas de CLI ni SQLite
# -------------------------------------------------------------------------

set -e

echo "[INIT] === Début first-run-init.sh (méthode API v2) ==="

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 1 : Attente que Forgejo soit prêt
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Attente que Forgejo soit prêt..."
ATTEMPT=0
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge 60 ]; then
    echo "[INIT] ERREUR: Timeout - Forgejo ne répond pas"
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
WOODPECKER_INTERNAL_URL="${WOODPECKER_INTERNAL_URL:-${WOODPECKER_HOST:-http://woodpecker-server:8000}}"
OAUTH_REDIRECT_URI="${WOODPECKER_INTERNAL_URL}/authorize"

echo "[INIT] Configuration:"
echo "[INIT]   Admin: $ADMIN_USER"
echo "[INIT]   Email: $ADMIN_EMAIL"
echo "[INIT]   Redirect URI: $OAUTH_REDIRECT_URI"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 3 : Installation via formulaire (si nécessaire)
# ══════════════════════════════════════════════════════════════════════════
if [ -f /data/gitea/forgejo.db ]; then
  echo "[INIT] ⚠ Forgejo déjà installé (DB existe)"
else
  echo "[INIT] Installation de Forgejo..."
  HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/ \
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
    -d "admin_email=$ADMIN_EMAIL")

  echo "[INIT]   Réponse HTTP: $HTTP_RESPONSE"
  echo "[INIT] ✓ Installation soumise, attente redémarrage..."
  
  sleep 5
  ATTEMPT=0
  until wget --quiet --spider http://localhost:3000/api/healthz 2>/dev/null; do
    ATTEMPT=$((ATTEMPT + 1))
    [ $ATTEMPT -ge 30 ] && echo "[INIT] ERREUR: Timeout redémarrage" && exit 1
    sleep 2
  done
  echo "[INIT] ✓ Serveur redémarré"
fi

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 4 : Création OAuth via API avec Basic Auth
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Création application OAuth via API (Basic Auth)..."

# Utiliser Basic Auth directement avec username:password
# C'est plus simple que de créer un token d'abord
OAUTH_RESPONSE=$(curl -s -X POST \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  http://localhost:3000/api/v1/user/applications/oauth2 \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Woodpecker CI\",
    \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"]
  }")

echo "[INIT] Réponse API reçue"

# Vérifier si jq est disponible
if command -v jq >/dev/null 2>&1; then
  # Extraction avec jq
  CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id // empty')
  CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret // empty')
else
  # Extraction manuelle sans jq (fallback BusyBox)
  CLIENT_ID=$(echo "$OAUTH_RESPONSE" | grep -o '"client_id":"[^"]*"' | cut -d'"' -f4)
  CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | grep -o '"client_secret":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "[INIT] ❌ ERREUR: Extraction des credentials échouée"
  echo "[INIT] Réponse API complète:"
  echo "$OAUTH_RESPONSE"
  
  # Vérifier si c'est une erreur d'authentification
  if echo "$OAUTH_RESPONSE" | grep -q "401\|Unauthorized\|authentication"; then
    echo "[INIT] ❌ Erreur d'authentification - vérifier credentials admin"
  fi
  
  exit 1
fi

echo "[INIT] ✓ Credentials OAuth récupérés!"
echo "[INIT]   Client ID: $CLIENT_ID"
echo "[INIT]   Client Secret: ${CLIENT_SECRET:0:8}..."

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 5 : Sauvegarde des credentials
# ══════════════════════════════════════════════════════════════════════════
SHARED_OAUTH_FILE="/shared/oauth-credentials.env"

echo "[INIT] Sauvegarde dans $SHARED_OAUTH_FILE..."
cat > "$SHARED_OAUTH_FILE" << EOF
# OAuth credentials générés via API
# Date: $(date -Iseconds 2>/dev/null || date)
WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID
WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET
EOF

chmod 644 "$SHARED_OAUTH_FILE"
chown git:git "$SHARED_OAUTH_FILE" 2>/dev/null || true

echo "[INIT] ✓ Credentials sauvegardés"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 6 : Affichage pour extraction
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          CREDENTIALS OAUTH GÉNÉRÉS AVEC SUCCÈS                 ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║ WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID"
echo "║ WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Credentials pour extraction automatique (au début de ligne)
echo "WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET"

# Signal de fin
echo "[INIT] ✅ Configuration OAuth terminée avec succès!"
echo "[INIT] first-run-init.sh terminé"

exit 0
