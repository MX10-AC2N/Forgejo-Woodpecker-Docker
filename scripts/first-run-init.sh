#!/bin/sh
# -------------------------------------------------------------------------
# first-run-init-api.sh – OAuth via API Forgejo (pas de scraping HTML)
# Solution alternative robuste utilisant l'API REST
# -------------------------------------------------------------------------

set -e

echo "[INIT] === Début first-run-init-api.sh (méthode API) ==="

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
echo "[INIT]   Redirect URI: $OAUTH_REDIRECT_URI"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 3 : Installation via formulaire (inchangé)
# ══════════════════════════════════════════════════════════════════════════
if [ -f /data/gitea/forgejo.db ]; then
  echo "[INIT] ⚠ Forgejo déjà installé"
else
  echo "[INIT] Installation de Forgejo..."
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

  echo "[INIT] Attente redémarrage..."
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
# ÉTAPE 4 : Création token d'accès via CLI (méthode alternative)
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Création token d'accès API via CLI Forgejo..."

# Utiliser la CLI Forgejo pour créer un token
# Cette méthode évite le scraping HTML
ACCESS_TOKEN=$(su-exec git forgejo admin user generate-access-token \
  --username "$ADMIN_USER" \
  --token-name "OAuth Setup Token" \
  --scopes "write:admin,write:user" \
  --raw 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "[INIT] ❌ Impossible de créer le token via CLI"
  echo "[INIT] Tentative méthode alternative..."
  
  # Méthode fallback: Créer le token directement en base de données
  # Cette approche est plus hacky mais fonctionne
  ACCESS_TOKEN="forgejo_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 40)"
  
  # Insérer le token dans la DB (nécessite connaissance du schéma)
  sqlite3 /data/gitea/forgejo.db << EOF
INSERT INTO access_token (uid, name, token, token_hash, token_salt, scope, created_unix, updated_unix)
VALUES (
  (SELECT id FROM user WHERE name='$ADMIN_USER'),
  'OAuth Setup Token',
  '$ACCESS_TOKEN',
  '',
  '',
  'all',
  strftime('%s', 'now'),
  strftime('%s', 'now')
);
EOF
fi

echo "[INIT] ✓ Token d'accès créé: ${ACCESS_TOKEN:0:20}..."

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 5 : Création OAuth via API
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Création application OAuth via API..."

OAUTH_RESPONSE=$(curl -s -X POST \
  http://localhost:3000/api/v1/user/applications/oauth2 \
  -H "Authorization: token $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Woodpecker CI\",
    \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"]
  }")

echo "[INIT] Réponse API reçue"

# Extraction avec jq (beaucoup plus fiable que le scraping HTML)
CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id // empty')
CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret // empty')

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "[INIT] ❌ ERREUR: Extraction des credentials échouée"
  echo "[INIT] Réponse API:"
  echo "$OAUTH_RESPONSE" | jq . 2>/dev/null || echo "$OAUTH_RESPONSE"
  exit 1
fi

echo "[INIT] ✓ Credentials OAuth récupérés!"
echo "[INIT]   Client ID: $CLIENT_ID"
echo "[INIT]   Client Secret: ${CLIENT_SECRET:0:8}..."

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 6 : Sauvegarde des credentials
# ══════════════════════════════════════════════════════════════════════════
SHARED_OAUTH_FILE="/shared/oauth-credentials.env"

echo "[INIT] Sauvegarde dans $SHARED_OAUTH_FILE..."
cat > "$SHARED_OAUTH_FILE" << EOF
# OAuth credentials générés via API
# Date: $(date -Iseconds)
WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID
WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET
EOF

chmod 644 "$SHARED_OAUTH_FILE"
chown git:git "$SHARED_OAUTH_FILE"

echo "[INIT] ✓ Credentials sauvegardés"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 7 : Affichage pour extraction
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
