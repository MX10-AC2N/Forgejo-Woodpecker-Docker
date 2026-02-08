#!/bin/bash
# =============================================================================
# Script de validation de la stack Forgejo + Woodpecker
# =============================================================================
set -euo pipefail

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher un message de succès
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Fonction pour afficher un message d'erreur
error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour afficher un message d'information
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Fonction pour afficher un message d'avertissement
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo ""
echo "=========================================="
echo "  🔍 VALIDATION DE LA STACK"
echo "  Forgejo + Woodpecker CI"
echo "=========================================="
echo ""

# =============================================================================
# 1. Vérifier que Docker Compose est disponible
# =============================================================================
info "Test 1/10: Vérification Docker Compose..."
if command -v docker compose &> /dev/null; then
    success "Docker Compose disponible ($(docker compose version))"
else
    error "Docker Compose n'est pas installé"
    exit 1
fi

# =============================================================================
# 2. Vérifier que la stack est démarrée
# =============================================================================
info "Test 2/10: Vérification de l'état des conteneurs..."
if docker compose ps | grep -q "forgejo"; then
    success "Les conteneurs sont démarrés"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
else
    error "Les conteneurs ne sont pas démarrés"
    info "Lancez d'abord : docker compose up -d"
    exit 1
fi

# =============================================================================
# 3. Vérifier le health de Forgejo
# =============================================================================
info "Test 3/10: Vérification health Forgejo..."
FORGEJO_PORT=${FORGEJO_HTTP_PORT:-5333}
if curl -sf "http://localhost:${FORGEJO_PORT}/api/healthz" >/dev/null 2>&1; then
    success "Forgejo est healthy (http://localhost:${FORGEJO_PORT})"
else
    error "Forgejo n'est pas healthy"
    warning "Vérifiez les logs : docker compose logs forgejo"
    exit 1
fi

# =============================================================================
# 4. Vérifier le health de Woodpecker
# =============================================================================
info "Test 4/10: Vérification health Woodpecker..."
WOODPECKER_PORT=${WOODPECKER_HTTP_PORT:-5444}
if curl -sf "http://localhost:${WOODPECKER_PORT}/healthz" >/dev/null 2>&1; then
    success "Woodpecker est healthy (http://localhost:${WOODPECKER_PORT})"
else
    error "Woodpecker n'est pas healthy"
    warning "Vérifiez les logs : docker compose logs woodpecker-server"
    exit 1
fi

# =============================================================================
# 5. Vérifier que OAuth est configuré dans Forgejo
# =============================================================================
info "Test 5/10: Vérification OAuth dans Forgejo..."
if docker compose logs forgejo 2>/dev/null | grep -q "first-run-init.sh terminé"; then
    success "OAuth créé dans Forgejo"
else
    warning "OAuth pas encore créé (peut être normal si premier démarrage récent)"
fi

# =============================================================================
# 6. Vérifier que les credentials OAuth sont disponibles
# =============================================================================
info "Test 6/10: Vérification credentials OAuth..."
OAUTH_CLIENT=$(docker compose logs forgejo 2>/dev/null | grep "^forgejo.*WOODPECKER_FORGEJO_CLIENT=" | tail -n1 | sed 's/.*WOODPECKER_FORGEJO_CLIENT=//' | tr -d '\r\n' | xargs)
OAUTH_SECRET=$(docker compose logs forgejo 2>/dev/null | grep "^forgejo.*WOODPECKER_FORGEJO_SECRET=" | tail -n1 | sed 's/.*WOODPECKER_FORGEJO_SECRET=//' | tr -d '\r\n' | xargs)

if [ -n "$OAUTH_CLIENT" ] && [ -n "$OAUTH_SECRET" ]; then
    success "Credentials OAuth trouvés"
    info "   CLIENT: ${OAUTH_CLIENT:0:36}"
    info "   SECRET: ${OAUTH_SECRET:0:24}..."
else
    warning "Credentials OAuth non trouvés dans les logs"
    info "Cela peut être normal si c'est un redémarrage"
fi

# =============================================================================
# 7. Vérifier que OAuth est chargé dans Woodpecker
# =============================================================================
info "Test 7/10: Vérification OAuth dans Woodpecker..."
CLIENT_IN_CONTAINER=$(docker compose exec -T woodpecker-server env 2>/dev/null | grep "^WOODPECKER_FORGEJO_CLIENT=" | cut -d= -f2 || echo "")
SECRET_IN_CONTAINER=$(docker compose exec -T woodpecker-server env 2>/dev/null | grep "^WOODPECKER_FORGEJO_SECRET=" | cut -d= -f2 || echo "")

if [ -n "$CLIENT_IN_CONTAINER" ] && [ -n "$SECRET_IN_CONTAINER" ]; then
    success "OAuth chargé dans Woodpecker"
    info "   CLIENT: ${CLIENT_IN_CONTAINER:0:36}"
    info "   SECRET: ${SECRET_IN_CONTAINER:0:24}..."
else
    error "OAuth NON chargé dans Woodpecker"
    warning "Actions à faire :"
    warning "  1. Vérifier que le fichier /shared/oauth-credentials.env existe"
    warning "  2. Redémarrer Woodpecker : docker compose restart woodpecker-server"
    
    # Vérifier si le fichier existe
    if docker compose exec -T forgejo test -f /shared/oauth-credentials.env 2>/dev/null; then
        info "Le fichier /shared/oauth-credentials.env existe"
        docker compose exec -T forgejo cat /shared/oauth-credentials.env
    else
        error "Le fichier /shared/oauth-credentials.env n'existe pas"
    fi
fi

# =============================================================================
# 8. Test de l'endpoint OAuth
# =============================================================================
info "Test 8/10: Test endpoint OAuth (/authorize)..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:${WOODPECKER_PORT}/authorize" || echo "000")

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 302 ] || [ "$HTTP_CODE" -eq 401 ]; then
    success "Endpoint OAuth OK (HTTP $HTTP_CODE)"
else
    error "Endpoint OAuth failed (HTTP $HTTP_CODE)"
    warning "Code 000 = connexion refusée, vérifier si Woodpecker est bien démarré"
fi

# =============================================================================
# 9. Vérifier que l'agent Woodpecker est connecté
# =============================================================================
info "Test 9/10: Vérification Woodpecker Agent..."
if docker compose logs woodpecker-agent 2>/dev/null | grep -q "starting Woodpecker agent\|registered with ID"; then
    success "Woodpecker Agent connecté"
else
    warning "Woodpecker Agent pas encore connecté ou erreur"
    info "Vérifiez : docker compose logs woodpecker-agent"
fi

# =============================================================================
# 10. Vérifier la synchronisation des volumes
# =============================================================================
info "Test 10/10: Vérification volumes..."
if docker compose exec -T forgejo ls /shared/ >/dev/null 2>&1; then
    success "Volume /shared accessible depuis Forgejo"
    docker compose exec -T forgejo ls -lah /shared/ || true
else
    error "Volume /shared non accessible"
fi

if docker compose exec -T woodpecker-server ls /shared/ >/dev/null 2>&1; then
    success "Volume /shared accessible depuis Woodpecker"
else
    error "Volume /shared non accessible depuis Woodpecker"
fi

# =============================================================================
# RÉSUMÉ FINAL
# =============================================================================
echo ""
echo "=========================================="
echo "  📊 RÉSUMÉ DE LA VALIDATION"
echo "=========================================="
echo ""

FORGEJO_STATUS="❌"
WOODPECKER_STATUS="❌"
OAUTH_STATUS="❌"
AGENT_STATUS="❌"

if curl -sf "http://localhost:${FORGEJO_PORT}/api/healthz" >/dev/null 2>&1; then
    FORGEJO_STATUS="✅"
fi

if curl -sf "http://localhost:${WOODPECKER_PORT}/healthz" >/dev/null 2>&1; then
    WOODPECKER_STATUS="✅"
fi

if [ -n "$CLIENT_IN_CONTAINER" ] && [ -n "$SECRET_IN_CONTAINER" ]; then
    OAUTH_STATUS="✅"
fi

if docker compose logs woodpecker-agent 2>/dev/null | grep -q "starting Woodpecker agent"; then
    AGENT_STATUS="✅"
fi

echo "Service Forgejo       : $FORGEJO_STATUS"
echo "Service Woodpecker    : $WOODPECKER_STATUS"
echo "Configuration OAuth   : $OAUTH_STATUS"
echo "Woodpecker Agent      : $AGENT_STATUS"
echo ""

if [ "$FORGEJO_STATUS" = "✅" ] && [ "$WOODPECKER_STATUS" = "✅" ] && [ "$OAUTH_STATUS" = "✅" ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ STACK VALIDÉE - TOUT FONCTIONNE !${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "🌐 URLs d'accès :"
    echo "   Forgejo    : http://localhost:${FORGEJO_PORT}"
    echo "   Woodpecker : http://localhost:${WOODPECKER_PORT}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  CERTAINS TESTS ONT ÉCHOUÉ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "📝 Commandes de debug utiles :"
    echo "   docker compose logs -f forgejo"
    echo "   docker compose logs -f woodpecker-server"
    echo "   docker compose logs -f woodpecker-agent"
    echo "   docker compose ps"
    echo ""
    exit 1
fi