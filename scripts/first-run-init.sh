#!/bin/sh
set -euo pipefail

echo "============================================================="
echo "  [INIT] Configuration automatique Forgejo + Woodpecker"
echo "============================================================="
echo ""

# Variables
ADMIN_USER="${ADMIN_USERNAME:-admin}"
ADMIN_PASS="${ADMIN_PASSWORD:-ChangeMe123!SecurePassword}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@forgejo.local}"
ADMIN_FULLNAME="${ADMIN_FULLNAME:-Administrator}"
OAUTH_REDIRECT_URI="${WOODPECKER_HOST:-http://localhost:5444}/authorize"

echo "Configuration:"
echo "  - Admin user: $ADMIN_USER"
echo "  - Admin email: $ADMIN_EMAIL"
echo "  - OAuth redirect: $OAUTH_REDIRECT_URI"
echo ""

# Attendre que l'API réponde
MAX_ATTEMPTS=60
ATTEMPT=0

echo "=== Étape 1: Attente que Forgejo soit prêt ==="
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "❌ ERREUR: Timeout après ${MAX_ATTEMPTS} tentatives"
    echo "=== Logs Forgejo (dernières 50 lignes) ==="
    docker compose logs forgejo --tail 50 2>/dev/null || echo "Impossible d'accéder aux logs Forgejo"
    exit 1
  fi
  echo "⏳ Forgejo pas encore prêt... (tentative $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 5
done

echo "✅ Forgejo répond !"

# Attendre que Forgejo soit vraiment prêt (pas juste healthcheck)
echo "⏳ Attente supplémentaire pour initialisation complète Forgejo..."
sleep 10

# Vérifier si Forgejo est prêt pour création admin
echo "=== Étape 2: Vérification état Forgejo pour création admin ==="
FORGEJO_READY="false"
ATTEMPT=0
until [ "$FORGEJO_READY" = "true" ]; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    echo "❌ ERREUR: Forgejo non prêt pour création admin après $MAX_ATTEMPTS tentatives"
    exit 1
  fi
  
  echo "🔍 Vérification état Forgejo ($ATTEMPT/$MAX_ATTEMPTS)..."
  
  # Tester si l'endpoint users est accessible
  if wget --quiet --tries=1 --spider http://localhost:3000/api/v1/users 2>/dev/null; then
    echo "✅ Endpoint /api/v1/users accessible"
    FORGEJO_READY="true"
  else
    echo "⏳ Endpoint /api/v1/users non accessible..."
    sleep 2
  fi
done

# Créer l'utilisateur admin
echo "=== Étape 3: Création utilisateur admin ==="

echo "📝 Envoi requête création admin..."
ADMIN_CREATION_RESPONSE=$(wget --quiet --output-document=- --server-response \
  --header='Content-Type: application/json' \
  --post-data="{
    \"username\": \"$ADMIN_USER\",
    \"password\": \"$ADMIN_PASS\",
    \"email\": \"$ADMIN_EMAIL\",
    \"full_name\": \"$ADMIN_FULLNAME\",
    \"must_change_password\": false
  }" \
  http://localhost:3000/api/v1/users 2>&1)

HTTP_STATUS=$(echo "$ADMIN_CREATION_RESPONSE" | grep "HTTP/" | tail -n1 | awk '{print $2}')

echo "📋 Réponse serveur:"
echo "$ADMIN_CREATION_RESPONSE" | grep -E "HTTP/|Content-Type|X-RateLimit" || echo "Aucun header pertinent trouvé"

if [ "$HTTP_STATUS" = "201" ]; then
  echo "✅ Admin créé avec succès (HTTP $HTTP_STATUS)"
else
  echo "❌ Échec création admin (HTTP $HTTP_STATUS)"
  echo "📋 Réponse complète:"
  echo "$ADMIN_CREATION_RESPONSE"
  
  # Vérifier si admin existe déjà
  if echo "$ADMIN_CREATION_RESPONSE" | grep -q "already exists"; then
    echo "⚠️ Admin existe déjà, poursuite du script..."
  else
    exit 1
  fi
fi

# Attendre que l'admin soit vraiment créé dans la base
echo "⏳ Attente validation admin dans la base (5 secondes)..."
sleep 5

# Récupérer token
echo "=== Étape 4: Récupération token admin ==="

echo "🔍 Tentative récupération token..."
TOKEN_RESPONSE=$(wget --quiet --output-document=- \
  --auth-no-challenge --user="$ADMIN_USER" --password="$ADMIN_PASS" \
  --header='Content-Type: application/json' \
  --post-data='{"name": "init-token-auto"}' \
  http://localhost:3000/api/v1/users/$ADMIN_USER/tokens 2>/dev/null || echo "{}")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.sha1' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Échec récupération token admin"
  echo "📋 Réponse complète:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Token admin obtenu avec succès"

# Créer OAuth
echo "=== Étape 5: Création application OAuth ==="

echo "📝 Envoi requête création OAuth..."
OAUTH_RESPONSE=$(wget --quiet --output-document=- \
  --header="Authorization: token $ADMIN_TOKEN" \
  --header='Content-Type: application/json' \
  --post-data="{
    \"name\": \"Woodpecker CI\",
    \"redirect_uris\": [\"$OAUTH_REDIRECT_URI\"],
    \"confidential_client\": true,
    \"scopes\": [\"repo,user:email,read:org,read:repository,write:repository\"]
  }" \
  http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 2>/dev/null || echo "{}")

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id' 2>/dev/null)
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret' 2>/dev/null)

if [ "$OAUTH_CLIENT_ID" != "null" ] && [ -n "$OAUTH_CLIENT_ID" ]; then
  echo "✅ OAuth créé avec succès !"
  echo "   Client ID: ${OAUTH_CLIENT_ID:0:20}..."
  echo "   Secret: ${OAUTH_CLIENT_SECRET:0:20}..."
  
  # Export vers fichier partagé
  mkdir -p /shared
  cat > /shared/.oauth-credentials << EOF
export WOODPECKER_FORGEJO_CLIENT="$OAUTH_CLIENT_ID"
export WOODPECKER_FORGEJO_SECRET="$OAUTH_CLIENT_SECRET"
EOF
  chmod 644 /shared/.oauth-credentials
  echo "✅ OAuth exporté vers /shared/.oauth-credentials"
else
  echo "❌ Échec création OAuth"
  echo "📋 Réponse complète:"
  echo "$OAUTH_RESPONSE"
  
  # Vérifier si OAuth existe déjà
  if echo "$OAUTH_RESPONSE" | grep -q "already exists"; then
    echo "⚠️ OAuth existe déjà, poursuite du script..."
    
    # Essayer d'extraire les credentials existants
    OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id' 2>/dev/null || echo "")
    OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret' 2>/dev/null || echo "")
    
    if [ -n "$OAUTH_CLIENT_ID" ] && [ "$OAUTH_CLIENT_ID" != "null" ]; then
      echo "✅ Credentials OAuth existants trouvés !"
      mkdir -p /shared
      cat > /shared/.oauth-credentials << EOF
export WOODPECKER_FORGEJO_CLIENT="$OAUTH_CLIENT_ID"
export WOODPECKER_FORGEJO_SECRET="$OAUTH_CLIENT_SECRET"
EOF
      chmod 644 /shared/.oauth-credentials
      echo "✅ Credentials exportés vers /shared/.oauth-credentials"
    fi
  else
    exit 1
  fi
fi

echo ""
echo "============================================================="
echo "  ✅ Initialisation terminée avec succès !"
echo "============================================================="
echo ""
echo "Prochaines étapes:"
echo "1. Vérifier que Woodpecker démarre avec OAuth configuré"
echo "2. Tester la connexion sur http://localhost:5444"
echo "3. Si problème, consulter les logs avec:"
echo "   docker compose logs forgejo | grep -i oauth"
echo ""