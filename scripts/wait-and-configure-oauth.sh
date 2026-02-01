#!/bin/bash
set -e

echo "============================================================="
echo "  Woodpecker OAuth Auto-Configuration"
echo "============================================================="

OAUTH_FILE="/shared/.oauth-credentials"
MAX_WAIT=180  # Réduire à 3 minutes (Forgejo devrait créer OAuth en 1-2 min)
ELAPSED=0

echo "⏳ Attente des credentials OAuth depuis Forgejo..."
echo "   (timeout: ${MAX_WAIT}s)"

# Attendre que le fichier OAuth soit créé par Forgejo
while [ ! -f "$OAUTH_FILE" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    if [ $((ELAPSED % 30)) -eq 0 ]; then  # Afficher toutes les 30s
        echo "   Attente... ${ELAPSED}s/${MAX_WAIT}s"
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ ! -f "$OAUTH_FILE" ]; then
    echo ""
    echo "⚠️ Timeout : fichier OAuth non trouvé après ${MAX_WAIT}s"
    echo "   Woodpecker démarrera SANS OAuth pré-configuré"
    echo ""
    echo "   Causes possibles :"
    echo "   - Forgejo n'a pas fini l'initialisation (normal en CI/CD lent)"
    echo "   - L'application OAuth existe déjà (redémarrage)"
    echo ""
    echo "   Solutions :"
    echo "   1. Attendre 2-3 minutes puis : docker compose restart woodpecker-server"
    echo "   2. Utiliser : ./scripts/configure-oauth.sh"
    echo "   3. Configuration manuelle (voir README.md)"
    echo ""
    echo "🚀 Démarrage de Woodpecker Server SANS OAuth..."
    echo "============================================================="
else
    echo "✅ Fichier OAuth trouvé !"
    
    # Charger les credentials
    source "$OAUTH_FILE"
    
    # Vérifier que les variables sont bien définies
    if [ -z "$WOODPECKER_FORGEJO_CLIENT" ] || [ -z "$WOODPECKER_FORGEJO_SECRET" ]; then
        echo "⚠️ Variables OAuth vides dans le fichier"
    else
        # Exporter les variables pour que Woodpecker les utilise
        export WOODPECKER_FORGEJO_CLIENT
        export WOODPECKER_FORGEJO_SECRET
        
        echo "✅ OAuth configuré automatiquement :"
        echo "   Client ID: ${WOODPECKER_FORGEJO_CLIENT:0:20}..."
        echo "   Secret: ${WOODPECKER_FORGEJO_SECRET:0:20}..."
    fi
    echo ""
    echo "🚀 Démarrage de Woodpecker Server AVEC OAuth configuré..."
    echo "============================================================="
fi

# Lancer Woodpecker avec ou sans les credentials OAuth
exec /bin/woodpecker-server