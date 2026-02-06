#!/bin/sh
# -------------------------------------------------------------------------
# first-run-init-api.sh – Version améliorée avec validation robuste
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
    echo "[INIT] ERREUR: Timeout - Forgejo ne répond pas après 5 minutes"
    exit 1
  fi
  echo "[INIT] Tentative $ATTEMPT/60..."
  sleep 5
done
echo "[INIT] ✓ Forgejo répond!"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 2 : Variables d'environnement avec validation
# ══════════════════════════════════════════════════════════════════════════
ADMIN_USER="${ADMIN_USERNAME:-forgejo-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"
WOODPECKER_INTERNAL_URL="${WOODPECKER_INTERNAL_URL:-${WOODPECKER_HOST:-http://woodpecker-server:8000}}"
OAUTH_REDIRECT_URI="${WOODPECKER_INTERNAL_URL}/authorize"

# Validation des variables requises
if [ -z "$ADMIN_PASS" ]; then
  echo "[INIT] ERREUR: ADMIN_PASSWORD non défini"
  exit 1
fi

echo "[INIT] Configuration:"
echo "[INIT]   Admin: $ADMIN_USER"
echo "[INIT]   Email: $ADMIN_EMAIL"
echo "[INIT]   Redirect URI: $OAUTH_REDIRECT_URI"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 3 : Installation via formulaire AVEC VALIDATION
# ══════════════════════════════════════════════════════════════════════════
if [ -f /data/gitea/forgejo.db ]; then
  echo "[INIT] ✓ Forgejo déjà installé (base existante)"
else
  echo "[INIT] Installation de Forgejo..."
  
  INSTALL_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:3000/ \
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
  
  HTTP_CODE=$(echo "$INSTALL_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
  echo "[INIT]   Réponse HTTP: $HTTP_CODE"
  
  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
    echo "[INIT] ERREUR: Installation échouée (HTTP $HTTP_CODE)"
    echo "[INIT] Réponse:"
    echo "$INSTALL_RESPONSE" | grep -v "HTTP_CODE:"
    exit 1
  fi
  
  echo "[INIT] ✓ Installation soumise, attente redémarrage..."
  sleep 10
  
  ATTEMPT=0
  until wget --quiet --spider http://localhost:3000/api/healthz 2>/dev/null; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge 30 ]; then
      echo "[INIT] ERREUR: Timeout redémarrage Forgejo"
      exit 1
    fi
    echo "[INIT]   Attente redémarrage... ($ATTEMPT/30)"
    sleep 2
  done
  echo "[INIT] ✓ Serveur redémarré"
fi

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 4 : Vérification de l'existence de l'admin
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Vérification de l'utilisateur admin..."
ADMIN_CHECK=$(curl -s http://localhost:3000/api/v1/admin/users \
  -H "Authorization: token dummy" 2>/dev/null || echo "")

if echo "$ADMIN_CHECK" | grep -q "unauthorized\|404\|401"; then
  echo "[INIT]   Authentification requise, tentative de création token inline..."
  
  # Alternative: utiliser l'API sans token pour vérifier si l'admin existe
  if ! sqlite3 /data/gitea/forgejo.db "SELECT id FROM user WHERE name='$ADMIN_USER'" 2>/dev/null | grep -q .; then
    echo "[INIT] ERREUR: Utilisateur admin '$ADMIN_USER' introuvable en base"
    echo "[INIT]   L'installation Forgejo n'a peut-être pas créé l'admin correctement"
    exit 1
  fi
  echo "[INIT] ✓ Admin trouvé en base"
fi

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 5 : Tentative création token AVEC FALLBACK ROBUSTE
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Création token d'accès API..."

# Méthode 1: CLI Forgejo
ACCESS_TOKEN=""
CLI_AVAILABLE=false

if command -v forgejo >/dev/null 2>&1; then
  echo "[INIT]   Tentative CLI Forgejo..."
  ACCESS_TOKEN=$(forgejo admin user generate-access-token \
    --username "$ADMIN_USER" \
    --token-name "OAuth Setup Token" \
    --scopes "all" \
    --raw 2>/dev/null) || ACCESS_TOKEN=""
  
  if [ -n "$ACCESS_TOKEN" ]; then
    CLI_AVAILABLE=true
    echo "[INIT] ✓ Token créé via CLI"
  fi
fi

# Méthode 2: Insertion SQLite directe (fallback)
if [ -z "$ACCESS_TOKEN" ]; then
  echo "[INIT]   Fallback: Insertion SQLite directe..."
  
  # Générer token aléatoire
  ACCESS_TOKEN="forgejo_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 48)"
  TOKEN_HASH=$(echo -n "$ACCESS_TOKEN" | sha256sum | cut -d' ' -f1)
  TOKEN_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
  
  # Vérifier que la base existe et est accessible
  if [ ! -f /data/gitea/forgejo.db ]; then
    echo "[INIT] ERREUR: Base de données non trouvée"
    exit 1
  fi
  
  # Insérer avec vérification
  INSERT_RESULT=$(sqlite3 /data/gitea/forgejo.db "
    INSERT INTO access_token (uid, name, token, token_hash, token_salt, scope, created_unix, updated_unix)
    VALUES (
      (SELECT id FROM user WHERE name='$ADMIN_USER'),
      'OAuth Setup Token',
      '$ACCESS_TOKEN',
      '$TOKEN_HASH',
      '$TOKEN_SALT',
      'all',
      strftime('%s', 'now'),
      strftime('%s', 'now')
    );
  " 2>&1)
  
  if [ $? -eq 0 ]; then
    echo "[INIT] ✓ Token inséré en base SQLite"
  else
    echo "[INIT] ERREUR insertion SQLite: $INSERT_RESULT"
    exit 1
  fi
fi

echo "[INIT] ✓ Token disponible: ${ACCESS_TOKEN:0:15}..."

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 6 : Création OAuth via API AVEC RETRY
# ══════════════════════════════════════════════════════════════════════════
echo "[INIT] Création application OAuth via API..."

MAX_RETRIES=3
RETRY_DELAY=5

for TRY in $(seq 1 $MAX_RETRIES); do
  echo "[INIT]   Tentative $TRY/$MAX_RETRIES..."
  
  OAUTH_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    "http://localhost:3000/api/v1/user/applications/oauth2" \
    -H "Authorization: token $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"Woodpecker CI\",
      \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"]
    }")
  
  HTTP_CODE=$(echo "$OAUTH_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
  RESPONSE_BODY=$(echo "$OAUTH_RESPONSE" | grep -v "HTTP_CODE:")
  
  if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "[INIT] ✓ OAuth créé avec succès"
    break
  else
    echo "[INIT]   Erreur HTTP $HTTP_CODE"
    echo "[INIT]   Réponse: $RESPONSE_BODY"
    if [ $TRY -lt $MAX_RETRIES ]; then
      echo "[INIT]   Nouvelle tentative dans ${RETRY_DELAY}s..."
      sleep $RETRY_DELAY
    fi
  fi
done

# Validation finale
if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "200" ]; then
  echo "[INIT] ERREUR: Impossible de créer l'application OAuth après $MAX_RETRIES tentatives"
  echo "[INIT]   Dernière réponse: $RESPONSE_BODY"
  exit 1
fi

# Extraction avec validation jq
CLIENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.client_id // empty')
CLIENT_SECRET=$(echo "$RESPONSE_BODY" | jq -r '.client_secret // empty')

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "[INIT] ERREUR: Extraction des credentials échouée"
  echo "[INIT] Réponse complète:"
  echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
  exit 1
fi

echo "[INIT] ✓ Credentials OAuth récupérés!"
echo "[INIT]   Client ID: $CLIENT_ID"
echo "[INIT]   Client Secret: ${CLIENT_SECRET:0:8}..."

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 7 : Sauvegarde des credentials AVEC VALIDATION
# ══════════════════════════════════════════════════════════════════════════
SHARED_OAUTH_FILE="/shared/oauth-credentials.env"

# Créer le répertoire si nécessaire
mkdir -p "$(dirname "$SHARED_OAUTH_FILE")"

echo "[INIT] Sauvegarde dans $SHARED_OAUTH_FILE..."
cat > "$SHARED_OAUTH_FILE" << EOF
# OAuth credentials générés via API
# Date: $(date -Iseconds)
WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID
WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET
EOF

if [ $? -ne 0 ]; then
  echo "[INIT] ERREUR: Échec de l'écriture du fichier de credentials"
  exit 1
fi

chmod 644 "$SHARED_OAUTH_FILE" 2>/dev/null || true
chown git:git "$SHARED_OAUTH_FILE" 2>/dev/null || true

echo "[INIT] ✓ Credentials sauvegardés"

# ══════════════════════════════════════════════════════════════════════════
# ÉTAPE 8 : Affichage pour extraction et signal de fin
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          CREDENTIALS OAUTH GÉNÉRÉS AVEC SUCCÈS                 ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║ WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID"
echo "║ WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Credentials pour extraction automatique
echo "WOODPECKER_FORGEJO_CLIENT=$CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$CLIENT_SECRET"

# Signal de fin
echo "[INIT] ✅ Configuration OAuth terminée avec succès!"
echo "[INIT] first-run-init.sh terminé"

exit 0