# 🚀 Forgejo + Woodpecker CI - Stack DevOps Sécurisée & Optimisée

## 📝 Description

Stack DevOps auto-hébergée combinant **Forgejo 14** (forge Git) et **Woodpecker CI** (CI/CD), déployée via Docker Compose. Configuration sécurisée, optimisée et production-ready.

## ✨ Caractéristiques

- **🔒 Sécurité renforcée** : Limites de ressources, socket Docker en read-only, secrets externalisés
- **⚡ Optimisé** : Rotation des logs, healthchecks complets, versions fixées
- **🔧 Maintenance automatisée** : Optimisation DB hebdomadaire, backups quotidiens
- **📦 Simplicité** : Configuration centralisée dans `.env`, auto-initialisation
- **🎯 Production-ready** : Gestion d'erreurs robuste, monitoring intégré

## 📋 Prérequis

| Composant | Version minimum | Recommandé |
|-----------|-----------------|------------|
| Docker Engine | 20.10+ | 24.0+ |
| Docker Compose | v2.0+ | v2.20+ |
| RAM disponible | 2 GB | 4 GB |
| Espace disque | 10 GB | 20 GB+ |
| Ports libres | 5333, 5222, 5444 | - |

## 🚀 Installation Rapide

```bash
# 1. Cloner le repository
git clone https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker

# 2. Copier et configurer l'environnement
cp .env.example .env

# 3. ⚠️ IMPORTANT : Éditer .env et modifier au minimum :
#    - WOODPECKER_AGENT_SECRET (générer avec : openssl rand -base64 48)
#    - ADMIN_PASSWORD (mot de passe admin fort)
nano .env

# 4. Lancer la stack
docker compose up -d --build

# 5. Vérifier les logs
docker compose logs -f

# 6. Accéder aux services
# Forgejo : http://localhost:5333
# Woodpecker : http://localhost:5444
🌐 Accès aux Services
Service
URL par défaut
Port
Description
Forgejo Web
http://localhost:5333
5333
Interface web de la forge
Forgejo SSH
ssh://git@localhost:5222
5222
Accès Git SSH
Woodpecker CI
http://localhost:5444
5444
Interface CI/CD
📁 Structure du Projet
Forgejo-Woodpecker-Docker/
├── docker-compose.yml          # ⚙️ Orchestration (limites ressources, healthchecks)
├── Dockerfile.forgejo          # 🐳 Image custom avec jq, curl, sqlite
├── .env.example                # 📝 Template de configuration
├── .env                        # 🔐 Configuration réelle (git-ignoré)
├── .gitignore                  # 🚫 Fichiers exclus du versioning
├── scripts/                    # 📜 Scripts de maintenance
│   ├── entrypoint-cron.sh      # Point d'entrée avec cron
│   ├── first-run-init.sh       # Auto-initialisation (admin + OAuth)
│   ├── backup.sh               # Backup quotidien (4h00)
│   └── optimize-db.sh          # Optimisation hebdomadaire (dim 3h00)
├── volumes/                    # 💾 Données persistantes (git-ignoré)
│   ├── forgejo/
│   ├── woodpecker-server/
│   └── woodpecker-agent/
├── backups/                    # 📦 Sauvegardes (git-ignoré)
└── logs/                       # 📋 Logs applicatifs (git-ignoré)
🔧 Configuration Détaillée
Variables d'Environnement Essentielles
🔐 Secrets (OBLIGATOIRE)
# Générer avec : openssl rand -base64 48
WOODPECKER_AGENT_SECRET=votre_secret_très_long_et_aléatoire_ici

# Mot de passe admin Forgejo (première connexion)
ADMIN_PASSWORD=UnMotDePasseTrèsSécurisé2026!
🌍 Configuration Réseau
# Domaine/IP publique
FORGEJO_DOMAIN=localhost              # ou forgejo.votredomaine.com
FORGEJO_ROOT_URL=http://localhost:5333/

# URLs pour Woodpecker
WOODPECKER_HOST=http://localhost:5444
WOODPECKER_FORGEJO_URL=http://forgejo:3000  # Communication inter-conteneurs
📦 Versions et Limites
# Version Woodpecker (recommandé : fixer une version stable)
WOODPECKER_VERSION=v2.7.1-alpine

# Workflows simultanés par agent
WOODPECKER_MAX_WORKFLOWS=2

# Chemin des volumes (optionnel)
VOLUMES_BASE=./volumes  # ou /opt/docker/forgejo/volumes en prod
🔑 Configuration OAuth (Auto-générée)
Lors du premier démarrage, le script first-run-init.sh :
✅ Crée automatiquement le compte admin
✅ Génère une application OAuth pour Woodpecker
✅ Affiche les credentials dans les logs
Pour voir les credentials OAuth générés :
docker compose logs forgejo | grep "WOODPECKER_FORGEJO_CLIENT"
Si vous devez recréer manuellement l'OAuth :
Connectez-vous à Forgejo : http://localhost:5333
Avatar → Paramètres → Applications
Nouvelle application OAuth2 :
Nom : Woodpecker CI
URL de redirection : http://localhost:5444/authorize
Scopes : cocher tous (ou au minimum repo, user:email, read:org)
Copiez le Client ID et Client Secret dans .env
Redémarrez Woodpecker : docker compose restart woodpecker-server
🛠️ Commandes Utiles
Gestion de la Stack
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Redémarrer un service
docker compose restart forgejo

# Voir les logs en temps réel
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f woodpecker-server

# Rebuild après modification
docker compose up -d --build

# Nettoyer complètement (⚠️ PERTE DE DONNÉES)
docker compose down -v
rm -rf volumes/ backups/ logs/
Backup et Restauration
# Backup manuel immédiat
docker compose exec forgejo /scripts/backup.sh

# Lister les backups
ls -lh backups/

# Restaurer un backup (exemple)
docker compose down
# Extraire le backup dans volumes/forgejo/
tar -xzf backups/forgejo-dump-YYYYMMDD-HHMMSS.tar.gz -C volumes/forgejo/
docker compose up -d
Maintenance
# Optimisation DB manuelle
docker compose exec forgejo /scripts/optimize-db.sh

# Voir les logs de maintenance
docker compose exec forgejo tail -f /data/log/forgejo-maintenance.log

# Voir les logs de backup
docker compose exec forgejo tail -f /data/log/forgejo-backup.log
🔒 Sécurité & Production
✅ Checklist de Sécurité
[x] Secrets externalisés (pas de valeurs hardcodées)
[x] Versions Docker fixées (pas de latest ou next)
[x] Limites de ressources CPU/RAM configurées
[x] Socket Docker en read-only (ro)
[x] Rotation des logs (max 10MB × 3 fichiers)
[x] Healthchecks sur tous les services
[x] Réseau isolé avec subnet dédié
[ ] HTTPS/TLS (à configurer avec reverse proxy)
[ ] Firewall (UFW/iptables)
[ ] Backups automatiques hors serveur
[ ] Monitoring externe (Prometheus/Grafana)
🛡️ Recommandations Production
HTTPS obligatoire : Utilisez un reverse proxy (Traefik, Nginx, Caddy)
Secrets robustes :
# Générer des secrets forts
openssl rand -base64 48
Socket Docker sécurisé : Pour production, envisager :
Docker-in-Docker (DinD)
Podman au lieu de Docker
Agent distant via gRPC
Backups externalisés :
# Exemple : sync vers S3
aws s3 sync backups/ s3://mon-bucket/forgejo-backups/
Monitoring : Ajouter Prometheus metrics
Voir le fichier SECURITY.md pour le guide complet de sécurisation.
📅 Maintenance Automatique
Tâche
Fréquence
Heure
Script
Optimisation DB
Hebdomadaire
Dimanche 3h00
optimize-db.sh
Backup complet
Quotidienne
Tous les jours 4h00
backup.sh
Rétention backups : 7 jours (configurable dans backup.sh)
Rétention DB backups : 30 jours (configurable dans optimize-db.sh)
🐛 Dépannage
Problème : Forgejo ne démarre pas
# Vérifier les logs
docker compose logs forgejo

# Vérifier les permissions
ls -la volumes/forgejo/
# Doit appartenir à UID 1000

# Corriger les permissions
sudo chown -R 1000:1000 volumes/forgejo/
Problème : Woodpecker ne se connecte pas à Forgejo
# Vérifier que OAuth est configuré
docker compose logs forgejo | grep "OAUTH"

# Vérifier les variables d'environnement
docker compose exec woodpecker-server env | grep WOODPECKER

# Redémarrer dans le bon ordre
docker compose restart forgejo
sleep 10
docker compose restart woodpecker-server
Problème : Agent Woodpecker déconnecté
# Vérifier que le secret est identique
docker compose exec woodpecker-server env | grep AGENT_SECRET
docker compose exec woodpecker-agent env | grep AGENT_SECRET

# Vérifier le réseau
docker compose exec woodpecker-agent ping woodpecker-server
🔄 Mises à Jour
# 1. Backup avant mise à jour
docker compose exec forgejo /scripts/backup.sh

# 2. Modifier la version dans .env
# WOODPECKER_VERSION=v2.8.0-alpine

# 3. Rebuilder et relancer
docker compose down
docker compose pull
docker compose up -d --build

# 4. Vérifier les logs
docker compose logs -f
📚 Documentation Officielle
Forgejo Documentation
Woodpecker CI Documentation
Docker Compose Reference
🆘 Support
Issues : https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker/issues
Forgejo Forum : https://codeberg.org/forgejo/forgejo/issues
Woodpecker Discord : https://discord.gg/woodpecker-ci
📄 Licence
MIT License - Voir fichier LICENSE
⚠️ Note importante : Cette stack est conçue pour un usage personnel ou petites équipes. Pour un usage en production à grande échelle, des ajustements supplémentaires sont recommandés (haute disponibilité, réplication, monitoring avancé).
---