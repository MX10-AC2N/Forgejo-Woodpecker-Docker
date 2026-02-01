#!/bin/bash
set -euo pipefail

echo "============================================================="
echo "  Configuration OAuth automatique Forgejo → Woodpecker"
echo "============================================================="
echo ""

# Extraire les credentials des logs Forgejo
echo "🔍 Recherche des credentials OAuth dans les logs Forgejo..."

OAUTH_CLIENT=$(docker compose logs forgejo 2>/dev/null | grep "WOODPECKER_FORGEJO_CLIENT=" | tail -n1 | sed 's/.*WOODPECKER_FORGEJO_CLIENT=//' | tr -d '\r\n')
OAUTH_SECRET=$(docker compose logs forgejo 2>/dev/null | grep "WOODPECKER_FORGEJO_SECRET=" | tail -n1 | sed 's/.*WOODPECKER_FORGEJO_SECRET=//' | tr -d '\r\n')

if [ -z "$OAUTH_CLIENT" ] || [ -z "$OAUTH_SECRET" ]; then
    echo "❌ Impossible de trouver les credentials OAuth dans les logs"
    echo ""
    echo "Causes possibles :"
    echo "  1. Forgejo n'a pas encore fini l'initialisation"
    echo "  2. L'application OAuth existe déjà (redémarrage)"
    echo ""
    echo "Solutions :"
    echo "  - Attendez quelques minutes et réessayez"
    echo "  - Vérifiez les logs : docker compose logs forgejo | grep -i oauth"
    echo "  - Configuration manuelle : voir README.md section OAuth"
    exit 1
fi

echo "✅ Credentials OAuth trouvés !"
echo ""
echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT"
echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_SECRET"
echo ""

# Mettre à jour le .env
if [ -f .env ]; then
    echo "📝 Mise à jour du fichier .env..."
    
    # Backup de .env
    cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
    echo "   → Backup créé : .env.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Remplacer ou ajouter les credentials
    if grep -q "^WOODPECKER_FORGEJO_CLIENT=" .env; then
        sed -i.tmp "s|^WOODPECKER_FORGEJO_CLIENT=.*|WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT|" .env && rm -f .env.tmp
        echo "   → WOODPECKER_FORGEJO_CLIENT mis à jour"
    else
        echo "" >> .env
        echo "# OAuth auto-configuré le $(date)" >> .env
        echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT" >> .env
        echo "   → WOODPECKER_FORGEJO_CLIENT ajouté"
    fi
    
    if grep -q "^WOODPECKER_FORGEJO_SECRET=" .env; then
        sed -i.tmp "s|^WOODPECKER_FORGEJO_SECRET=.*|WOODPECKER_FORGEJO_SECRET=$OAUTH_SECRET|" .env && rm -f .env.tmp
        echo "   → WOODPECKER_FORGEJO_SECRET mis à jour"
    else
        echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_SECRET" >> .env
        echo "   → WOODPECKER_FORGEJO_SECRET ajouté"
    fi
    
    echo ""
    echo "✅ Fichier .env mis à jour avec succès !"
else
    echo "⚠️ Fichier .env non trouvé dans le répertoire courant"
    echo ""
    echo "Créez un fichier .env avec au minimum ces lignes :"
    echo ""
    echo "WOODPECKER_FORGEJO_CLIENT=$OAUTH_CLIENT"
    echo "WOODPECKER_FORGEJO_SECRET=$OAUTH_SECRET"
    echo ""
    exit 1
fi

echo ""
echo "============================================================="
echo "  🚀 Prochaines étapes"
echo "============================================================="
echo ""
echo "1. Redémarrer Woodpecker Server pour appliquer les changements :"
echo "   docker compose restart woodpecker-server"
echo ""
echo "2. Attendre que Woodpecker redémarre (~10-15 secondes) :"
echo "   docker compose logs -f woodpecker-server"
echo ""
echo "3. Tester la connexion OAuth :"
echo "   → Ouvrir http://localhost:5444"
echo "   → Cliquer sur 'Login'"
echo "   → Vous devriez être redirigé vers Forgejo"
echo ""
echo "============================================================="