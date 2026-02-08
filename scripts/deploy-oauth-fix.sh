#!/bin/bash
# -------------------------------------------------------------------------
# deploy-oauth-fix.sh - Déploiement automatique de la correction OAuth
# -------------------------------------------------------------------------

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     DÉPLOIEMENT CORRECTION OAUTH FORGEJO-WOODPECKER          ║
║                                                               ║
║     Version 2.0 - BusyBox Compatible                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Détection du répertoire du projet
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}📂 Répertoire du projet: $PROJECT_ROOT${NC}"
echo ""

# Fonction de vérification
check_file() {
    if [ ! -f "$1" ]; then
        echo -e "${RED}❌ ERREUR: Fichier manquant: $1${NC}"
        exit 1
    fi
}

# Fonction de confirmation
confirm() {
    read -p "$1 (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  Opération annulée${NC}"
        exit 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════
# ÉTAPE 1 : Vérifications préliminaires
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÉTAPE 1/6 : Vérifications préliminaires${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "$SCRIPT_DIR/first-run-init.sh" ]; then
    echo -e "${RED}❌ ERREUR: Ce script doit être exécuté depuis oauth-fix-package/${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Répertoire valide"

# Vérifier la présence de docker-compose
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ ERREUR: Docker n'est pas installé${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker installé"

if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ ERREUR: docker compose n'est pas disponible${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker Compose installé"

# Vérifier la présence des fichiers requis
check_file "$SCRIPT_DIR/first-run-init.sh"
check_file "$SCRIPT_DIR/Dockerfile.forgejo"

echo -e "${GREEN}✓${NC} Tous les fichiers requis présents"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# ÉTAPE 2 : Backup (optionnel)
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÉTAPE 2/6 : Sauvegarde (optionnel)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

BACKUP_DIR="$PROJECT_ROOT/backups/pre-oauth-fix-$(date +%Y%m%d-%H%M%S)"

if [ -f "$PROJECT_ROOT/first-run-init.sh" ] || [ -f "$PROJECT_ROOT/Dockerfile.forgejo" ]; then
    echo -e "${YELLOW}Des fichiers existants vont être remplacés.${NC}"
    read -p "Créer une sauvegarde ? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$BACKUP_DIR"
        [ -f "$PROJECT_ROOT/first-run-init.sh" ] && cp "$PROJECT_ROOT/first-run-init.sh" "$BACKUP_DIR/"
        [ -f "$PROJECT_ROOT/Dockerfile.forgejo" ] && cp "$PROJECT_ROOT/Dockerfile.forgejo" "$BACKUP_DIR/"
        echo -e "${GREEN}✓${NC} Sauvegarde créée: $BACKUP_DIR"
    fi
else
    echo -e "${GREEN}✓${NC} Aucun fichier existant à sauvegarder"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# ÉTAPE 3 : Copie des fichiers corrigés
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÉTAPE 3/6 : Copie des fichiers corrigés${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "📋 Copie de first-run-init.sh..."
cp "$SCRIPT_DIR/first-run-init.sh" "$PROJECT_ROOT/"
chmod +x "$PROJECT_ROOT/first-run-init.sh"
echo -e "${GREEN}✓${NC} first-run-init.sh copié"

echo "📋 Copie de Dockerfile.forgejo..."
cp "$SCRIPT_DIR/Dockerfile.forgejo" "$PROJECT_ROOT/"
echo -e "${GREEN}✓${NC} Dockerfile.forgejo copié"

echo ""

# ═══════════════════════════════════════════════════════════════════════
# ÉTAPE 4 : Arrêt de la stack existante
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÉTAPE 4/6 : Arrêt de la stack existante${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_ROOT"

if docker compose ps | grep -q "forgejo"; then
    echo -e "${YELLOW}⚠️  Stack en cours d'exécution détectée${NC}"
    confirm "Arrêter la stack existante ?"
    
    echo "🛑 Arrêt de la stack..."
    docker compose down
    echo -e "${GREEN}✓${NC} Stack arrêtée"
else
    echo -e "${GREEN}✓${NC} Aucune stack en cours d'exécution"
fi

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Pour une configuration OAuth propre, il est recommandé${NC}"
echo -e "${YELLOW}   de supprimer les volumes existants.${NC}"
echo ""
confirm "Supprimer les volumes existants (rm -rf volumes/) ?"

echo "🗑️  Suppression des volumes..."
rm -rf volumes/
echo -e "${GREEN}✓${NC} Volumes supprimés"

echo ""

# ═══════════════════════════════════════════════════════════════════════
# ÉTAPE 5 : Rebuild de l'image Forgejo
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÉTAPE 5/6 : Rebuild de l'image Forgejo${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "🔨 Build de l'image Forgejo (cela peut prendre 1-2 minutes)..."
docker compose build --no-cache forgejo

echo -e "${GREEN}✓${NC} Image Forgejo rebuilt avec succès"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# ÉTAPE 6 : Démarrage de la stack
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÉTAPE 6/6 : Démarrage de la stack${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "🚀 Démarrage de la stack..."
docker compose up -d

echo -e "${GREEN}✓${NC} Stack démarrée"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Monitoring des logs
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}MONITORING : Surveillance du processus OAuth${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "📊 Surveillance des logs Forgejo (Ctrl+C pour arrêter)..."
echo -e "${YELLOW}Recherche du message de succès OAuth...${NC}"
echo ""

# Timeout de 5 minutes
TIMEOUT=300
ELAPSED=0
SUCCESS=false

while [ $ELAPSED -lt $TIMEOUT ]; do
    if docker compose logs forgejo 2>/dev/null | grep -q "Configuration OAuth terminée avec succès"; then
        SUCCESS=true
        break
    fi
    
    if docker compose logs forgejo 2>/dev/null | grep -q "ERREUR.*CSRF"; then
        echo -e "${RED}❌ ERREUR détectée dans les logs (CSRF)${NC}"
        break
    fi
    
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
done

echo ""
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Résultat final
# ═══════════════════════════════════════════════════════════════════════
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}RÉSULTAT DU DÉPLOIEMENT${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if [ "$SUCCESS" = true ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                   ║${NC}"
    echo -e "${GREEN}║    ✅  DÉPLOIEMENT RÉUSSI !                       ║${NC}"
    echo -e "${GREEN}║                                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}OAuth configuré avec succès !${NC}"
    echo ""
    
    # Afficher les credentials si disponibles
    if docker compose exec -T forgejo test -f /shared/oauth-credentials.env 2>/dev/null; then
        echo -e "${BLUE}Credentials OAuth:${NC}"
        docker compose exec -T forgejo cat /shared/oauth-credentials.env | grep "WOODPECKER_FORGEJO"
        echo ""
    fi
    
    echo -e "${BLUE}Prochaines étapes:${NC}"
    echo "  1. Vérifier Woodpecker: http://localhost:5444"
    echo "  2. Se connecter avec votre compte Forgejo"
    echo "  3. Créer votre premier pipeline"
    echo ""
    
else
    echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                   ║${NC}"
    echo -e "${RED}║    ⚠️  DÉPLOIEMENT EN COURS OU ÉCHEC              ║${NC}"
    echo -e "${RED}║                                                   ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Le déploiement n'a pas confirmé le succès OAuth.${NC}"
    echo ""
    echo -e "${BLUE}Actions recommandées:${NC}"
    echo "  1. Vérifier les logs: docker compose logs forgejo -f | grep INIT"
    echo "  2. Vérifier le fichier OAuth: docker compose exec forgejo cat /shared/oauth-credentials.env"
    echo "  3. Consulter la documentation: OAUTH_FIX_DOCUMENTATION.md"
    echo ""
fi

# Status des services
echo -e "${BLUE}Status des services:${NC}"
docker compose ps

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Déploiement terminé !${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
