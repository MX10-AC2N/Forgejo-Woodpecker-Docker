#!/bin/sh
set -e

# =============================================================================
# first-run-init.sh - Auto-init Forgejo au premier démarrage
# Exécuté une seule fois via l'entrypoint
# =============================================================================

echo "=== [INIT] Attente que Forgejo soit prêt ==="

# Attendre que l'API réponde (healthz)
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz 2>/dev/null; do
  echo "Forgejo pas encore prêt... (sleep 5s)"
  sleep 5
done

echo "Forgejo répond ! Lancement initialisation..."

# ──────────────────────────────────────────────
# Variables (à adapter si besoin – ou passer via .env)
# ──────────────────────────────────────────────

ADMIN_USER="admin"
ADMIN_PASS="SuperMotDePasseTresLongEtSecure2026!"
ADMIN_EMAIL="admin@forgejo.local"
ADMIN_FULLNAME="Admin Initial"

OAUTH_APP_NAME="Woodpecker CI"
OAUTH_REDIRECT_URI="http://192.168.1.192:5444/authorize"   # ← À ADAPTER selon ton WOODPECKER_HOST
OAUTH_SCOPES="repo,user:email,read:org,read:repository,write:repository"

# ──────────────────────────────────────────────
# Créer l'utilisateur admin
# ──────────────────────────────────────────────

echo "Création utilisateur admin..."

curl -s -X POST http://localhost:3000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "'"$ADMIN_USER"'",
    "password": "'"$ADMIN_PASS"'",
    "email": "'"$ADMIN_EMAIL"'",
    "full_name": "'"$ADMIN_FULLNAME"'",
    "must_change_password": false,
    "admin": true
  }' || echo "Admin existe déjà (OK)"

# Récupérer un token admin pour les étapes suivantes
echo "Récupération token admin..."
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/users/$ADMIN_USER/tokens \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d '{"name": "init-token-auto"}' | jq -r '.sha1')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "ERREUR : impossible de récupérer le token admin"
  exit 1
fi

echo "Token admin obtenu"

# ──────────────────────────────────────────────
# Créer l'application OAuth pour Woodpecker
# ──────────────────────────────────────────────

echo "Création application OAuth Woodpecker..."

OAUTH_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$OAUTH_APP_NAME"'",
    "redirect_uris": ["'"$OAUTH_REDIRECT_URI"'"],
    "confidential_client": true,
    "scopes": ["'"$OAUTH_SCOPES"'"]
  }')

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id')
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret')

if [ "$OAUTH_CLIENT_ID" = "null" ] || [ -z "$OAUTH_CLIENT_ID" ]; then
  echo "ERREUR création OAuth : $OAUTH_RESPONSE"
  exit 1
fi

echo ""
echo "============================================================="
echo "  CONFIGURATION AUTO-GÉNÉRÉE – À AJOUTER DANS VOTRE .env"
echo "============================================================="
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
echo ""
echo "Connectez-vous à Forgejo : http://192.168.1.192:5333"
echo "Utilisateur admin : $ADMIN_USER / $ADMIN_PASS"
echo "============================================================="
echo ""

# ──────────────────────────────────────────────
# Créer un dépôt exemple avec notice
# ──────────────────────────────────────────────

echo "Création dépôt exemple 'documentation'..."
curl -s -X POST http://localhost:3000/api/v1/user/repos \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "documentation",
    "description": "Notice d'utilisation Forgejo + Woodpecker",
    "private": false,
    "auto_init": true,
    "default_branch": "main"
  }' || echo "Dépôt documentation existe déjà (OK)"

echo "Initialisation terminée !"