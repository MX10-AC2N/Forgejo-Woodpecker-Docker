#!/bin/sh
# =============================================================================
# Entrypoint pour Woodpecker Server avec auto-configuration OAuth
# =============================================================================
set -e

echo "[WOODPECKER-ENTRYPOINT] Démarrage Woodpecker Server..."

# =============================================================================
# 1. Chargement des credentials OAuth depuis le volume partagé (si disponible)
# =============================================================================
OAUTH_FILE="/shared/oauth-credentials.env"

if [ -f "$OAUTH_FILE" ]; then
    echo "[WOODPECKER-ENTRYPOINT] ✅ Fichier OAuth trouvé : $OAUTH_FILE"
    
    # Sourcer le fichier pour charger les variables
    . "$OAUTH_FILE"
    
    # Exporter les variables pour qu'elles soient disponibles pour Woodpecker
    if [ -n "$WOODPECKER_FORGEJO_CLIENT" ] && [ -n "$WOODPECKER_FORGEJO_SECRET" ]; then
        export WOODPECKER_FORGEJO_CLIENT
        export WOODPECKER_FORGEJO_SECRET
        echo "[WOODPECKER-ENTRYPOINT] ✅ Credentials OAuth chargés :"
        echo "   CLIENT: ${WOODPECKER_FORGEJO_CLIENT:0:36}"
        echo "   SECRET: ${WOODPECKER_FORGEJO_SECRET:0:24}..."
    else
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  Fichier OAuth existe mais les variables sont vides"
    fi
else
    echo "[WOODPECKER-ENTRYPOINT] ℹ️  Pas de fichier OAuth ($OAUTH_FILE) - démarrage sans credentials"
    echo "[WOODPECKER-ENTRYPOINT] ℹ️  L'authentification devra être configurée manuellement"
fi

# =============================================================================
# 2. Affichage de la configuration (pour debug)
# =============================================================================
if [ "${WOODPECKER_LOG_LEVEL}" = "debug" ] || [ "${WOODPECKER_LOG_LEVEL}" = "trace" ]; then
    echo ""
    echo "[WOODPECKER-ENTRYPOINT] === Configuration Woodpecker ==="
    echo "   WOODPECKER_HOST: ${WOODPECKER_HOST:-<non défini>}"
    echo "   WOODPECKER_FORGEJO: ${WOODPECKER_FORGEJO:-false}"
    echo "   WOODPECKER_FORGEJO_URL: ${WOODPECKER_FORGEJO_URL:-<non défini>}"
    echo "   WOODPECKER_FORGEJO_CLIENT: ${WOODPECKER_FORGEJO_CLIENT:+<défini (${#WOODPECKER_FORGEJO_CLIENT} chars)>}"
    echo "   WOODPECKER_FORGEJO_SECRET: ${WOODPECKER_FORGEJO_SECRET:+<défini (${#WOODPECKER_FORGEJO_SECRET} chars)>}"
    echo "   WOODPECKER_OPEN: ${WOODPECKER_OPEN:-false}"
    echo "   WOODPECKER_SERVER_ADDR: ${WOODPECKER_SERVER_ADDR:-0.0.0.0:8000}"
    echo "========================================"
    echo ""
fi

# =============================================================================
# 3. Validation des credentials OAuth
# =============================================================================
if [ "${WOODPECKER_FORGEJO}" = "true" ]; then
    if [ -z "$WOODPECKER_FORGEJO_CLIENT" ] || [ -z "$WOODPECKER_FORGEJO_SECRET" ]; then
        echo ""
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  ================================================"
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  ATTENTION : WOODPECKER_FORGEJO=true"
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  mais les credentials OAuth ne sont pas définis !"
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  "
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  Actions à faire :"
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  1. Attendre que Forgejo crée l'application OAuth"
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  2. Redémarrer ce conteneur : "
        echo "[WOODPECKER-ENTRYPOINT] ⚠️     docker compose restart woodpecker-server"
        echo "[WOODPECKER-ENTRYPOINT] ⚠️  ================================================"
        echo ""
    else
        echo "[WOODPECKER-ENTRYPOINT] ✅ Configuration OAuth validée - prêt pour Forgejo"
    fi
fi

# =============================================================================
# 4. Lancement de Woodpecker Server
# =============================================================================
echo "[WOODPECKER-ENTRYPOINT] 🚀 Lancement du serveur Woodpecker..."
echo ""

# Exécuter le point d'entrée original de l'image Woodpecker
exec /bin/woodpecker-server "$@"
