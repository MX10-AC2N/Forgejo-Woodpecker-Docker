#!/bin/sh
set -e

# ================================================
#  first-run-init.sh - Initialisation automatique
# ================================================

# Attendre que Forgejo soit vraiment prêt (API répond)
echo "Attente que Forgejo soit prêt..."
until wget --quiet --tries=1 --spider http://localhost:3000/api/healthz; do
  echo "Forgejo pas encore prêt... (sleep 5s)"
  sleep 5
done
echo "Forgejo répond ! Démarrage initialisation..."

# Variables (à adapter ou passer via .env si besoin)
ADMIN_USER="admin"
ADMIN_PASS="TonMotDePasseTrèsLongEtSécurisé123!"
ADMIN_EMAIL="admin@forgejo.local"
OAUTH_APP_NAME="Woodpecker CI"
OAUTH_REDIRECT="http://192.168.1.192:5444/authorize"
OAUTH_SCOPES="repo,user:email,read:org,read:repository,write:repository"

# Créer l'utilisateur admin (si n'existe pas)
echo "Création utilisateur admin..."
curl -s -X POST http://localhost:3000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "'"$ADMIN_USER"'",
    "password": "'"$ADMIN_PASS"'",
    "email": "'"$ADMIN_EMAIL"'",
    "full_name": "Admin User",
    "must_change_password": false,
    "admin": true
  }' || echo "Admin existe déjà (OK)"

# Récupérer le token admin
echo "Récupération token admin..."
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/users/$ADMIN_USER/tokens \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d '{"name": "init-token"}' | jq -r '.sha1')

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Erreur : impossible de récupérer le token admin"
  exit 1
fi

# Créer l'application OAuth pour Woodpecker
echo "Création application OAuth Woodpecker..."
OAUTH_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/users/$ADMIN_USER/applications/oauth2 \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$OAUTH_APP_NAME"'",
    "redirect_uris": ["'"$OAUTH_REDIRECT"'"],
    "confidential_client": true,
    "scopes": ["'"$OAUTH_SCOPES"'"]
  }')

OAUTH_CLIENT_ID=$(echo "$OAUTH_RESPONSE" | jq -r '.client_id')
OAUTH_CLIENT_SECRET=$(echo "$OAUTH_RESPONSE" | jq -r '.client_secret')

if [ "$OAUTH_CLIENT_ID" = "null" ]; then
  echo "Erreur création OAuth : $OAUTH_RESPONSE"
  exit 1
fi

echo "======================================"
echo "  WOODPECKER CONFIG AUTO-GÉNÉRÉE"
echo "======================================"
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT_ID"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_CLIENT_SECRET"
echo "======================================"
echo "Ajoutez ces lignes dans votre .env puis relancez woodpecker-server"

# Créer un dépôt exemple avec notice
echo "Création dépôt exemple 'documentation'..."
curl -s -X POST http://localhost:3000/api/v1/user/repos \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "documentation",
    "description": "Notice Forgejo + Woodpecker",
    "private": false,
    "auto_init": true,
    "default_branch": "main"
  }'

# (Optionnel) Ajouter README avec notice
# Pour l'instant on peut le faire manuellement après, ou via git push depuis le script

echo "Initialisation terminée !"
echo "Vous pouvez maintenant vous connecter avec $ADMIN_USER / $ADMIN_PASS"