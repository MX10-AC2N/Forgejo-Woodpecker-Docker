#!/bin/bash
set -e

echo "============================================================="
echo "  Woodpecker OAuth Auto-Configuration"
echo "============================================================="

OAUTH_FILE="/shared/.oauth-credentials"
MAX_WAIT=300  # 5 minutes max
ELAPSED=0

echo "⏳ Attente des credentials OAuth depuis Forgejo..."

# Attendre que le fichier OAuth soit créé par Forgejo
while [ ! -f "$OAUTH_FILE" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    echo "   Attente... ${ELAPSED}s/${MAX_WAIT}s"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ ! -f "$OAUTH_FILE" ]; then
    echo "⚠️ Timeout : fichier OAuth non trouvé après ${MAX_WAIT}s"
    echo "   Woodpecker démarrera sans OAuth pré-configuré"
    echo "   Utilisez le script configure-oauth.sh après le démarrage"
    echo ""
else
    echo "✅ Fichier OAuth trouvé !"
    
    # Charger les credentials
    source "$OAUTH_FILE"
    
    # Exporter les variables pour que Woodpecker les utilise
    export WOODPECKER_FORGEJO_CLIENT
    export WOODPECKER_FORGEJO_SECRET
    
    echo "✅ OAuth configuré automatiquement :"
    echo "   Client ID: ${WOODPECKER_FORGEJO_CLIENT:0:20}..."
    echo "   Secret: ${WOODPECKER_FORGEJO_SECRET:0:20}..."
    echo ""
fi

echo "🚀 Démarrage de Woodpecker Server..."
echo "============================================================="

# Lancer Woodpecker avec les credentials OAuth chargés
exec /bin/woodpecker-server