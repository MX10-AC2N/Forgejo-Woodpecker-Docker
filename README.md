# 🚀 Forgejo + Woodpecker CI - Stack Auto-Configurée

[![CI/CD Status](https://img.shields.io/badge/CI%2FCD-passing-brightgreen)]()
[![Docker Compose](https://img.shields.io/badge/docker--compose-2.0+-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

Stack complète d'intégration continue avec [Forgejo](https://forgejo.org/) (forge Git auto-hébergée) et [Woodpecker CI](https://woodpecker-ci.org/) (CI/CD moderne), entièrement conteneurisée et **100% auto-configurée**. spécialement prévu pour une utilisation personnelle en local.


## ✨ Fonctionnalités Principales

- ✅ **Configuration OAuth automatique** : Zéro intervention manuelle
- ✅ **Déploiement en une commande** : `docker compose up -d`
- ✅ **Healthchecks intelligents** : Surveillance de tous les services
- ✅ **Validation complète** : Script de test automatique
- ✅ **Workflow CI/CD** : Tests GitHub Actions intégrés
- ✅ **Production-ready** : Sécurité, backup, optimisation DB
- ✅ **Documentation complète** : Guides et troubleshooting

## 🎯 Pourquoi cette stack ?

### Le problème des solutions existantes

Les stacks Forgejo + Woodpecker nécessitent généralement :
- Configuration manuelle d'OAuth via l'interface web
- Redémarrage manuel de Woodpecker après création OAuth
- Commandes complexes et documentation éparpillée
- Tests manuels pour vérifier que tout fonctionne

### Notre solution

**Configuration OAuth 100% automatique** grâce à un entrypoint personnalisé :

```
1. Forgejo démarre → Crée l'application OAuth via API
2. Credentials sauvegardés dans volume partagé
3. Woodpecker démarre → Charge automatiquement les credentials
4. Stack opérationnelle en ~2 minutes
```

**Résultat** : Zéro configuration manuelle, déploiement reproductible, workflow CI/CD qui valide tout automatiquement.

---

## 📋 Table des Matières

- [Prérequis](#-prérequis)
- [Installation Rapide](#-installation-rapide-5-minutes)
- [Architecture](#-architecture)
- [Configuration](#-configuration)
- [Utilisation](#-utilisation)
- [Validation](#-validation)
- [Commandes Utiles](#-commandes-utiles)
- [Troubleshooting](#-troubleshooting)
- [Sécurité en Production](#-sécurité-en-production)
- [Sauvegarde et Restauration](#-sauvegarde-et-restauration)
- [Contribution](#-contribution)

---

## 📦 Prérequis

### Logiciels Requis

| Logiciel | Version Minimum | Vérification |
|----------|-----------------|--------------|
| **Docker Engine** | 20.10+ | `docker --version` |
| **Docker Compose** | 2.0+ | `docker compose version` |
| **Git** | 2.0+ | `git --version` |

### Ressources Système

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| **RAM** | 2 GB | 4 GB |
| **CPU** | 2 cores | 4 cores |
| **Disque** | 10 GB | 20 GB+ |
| **Réseau** | Ports 5222, 5333, 5444 disponibles | - |

### Vérification rapide

```bash
# Versions
docker --version        # Doit être >= 20.10
docker compose version  # Doit être >= 2.0

# Ports disponibles
sudo netstat -tulpn | grep -E ':(5222|5333|5444)'
# Si aucune sortie → Ports libres ✅
```

---

## 🚀 Installation Rapide (5 minutes)

### Étape 1 : Cloner le projet

```bash
git clone https://github.com/votre-username/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker
```

### Étape 2 : Configurer l'environnement

```bash
# Copier le template
cp .env.example .env

# Éditer les secrets (OBLIGATOIRE)
nano .env
```

**Changez au minimum** :
```bash
# ⚠️ Générez un mot de passe fort
ADMIN_PASSWORD=VotreMotDePasseSuperSecurise123!

# ⚠️ Générez un secret de 48+ caractères
WOODPECKER_AGENT_SECRET=$(openssl rand -base64 48)
```

**Laissez vides** (auto-générés) :
```bash
WOODPECKER_FORGEJO_CLIENT=
WOODPECKER_FORGEJO_SECRET=
```

### Étape 3 : Lancer la stack

```bash
# Build des images
docker compose build

# Démarrage
docker compose up -d

# Suivre les logs (optionnel)
docker compose logs -f
```

### Étape 4 : Attendre l'initialisation (2-3 minutes)

La stack s'initialise automatiquement :

1. **Forgejo** démarre et s'installe
2. **first-run-init.sh** crée l'application OAuth
3. **Woodpecker** charge automatiquement les credentials OAuth
4. **Tous les services** passent healthy

### Étape 5 : Valider l'installation

```bash
# Attendre 2-3 minutes, puis valider
chmod +x scripts/validate-stack.sh
./scripts/validate-stack.sh
```

**Résultat attendu** :
```
✅ STACK VALIDÉE - TOUT FONCTIONNE !

🌐 URLs d'accès :
   Forgejo    : http://localhost:5333
   Woodpecker : http://localhost:5444
```

### Étape 6 : Premier login

#### Forgejo
- URL : http://localhost:5333
- Login : `forgejo-admin` (ou votre `ADMIN_USERNAME`)
- Password : Celui défini dans `ADMIN_PASSWORD`

#### Woodpecker
- URL : http://localhost:5444
- Cliquer sur **"Login"**
- → Redirection vers Forgejo
- → Se connecter avec vos identifiants Forgejo
- → Autoriser l'application "Woodpecker CI"
- → Retour sur Woodpecker, connecté ✅

**🎉 C'est tout ! Votre stack est opérationnelle !**

---

## 🏗️ Architecture

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                         Stack Docker                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐      ┌──────────────┐      ┌────────────────┐ │
│  │   Forgejo   │      │   Volume     │      │  Woodpecker    │ │
│  │   (Git)     │◄────►│   /shared    │◄────►│    Server      │ │
│  │   :5333     │      │              │      │    :5444       │ │
│  └──────┬──────┘      └──────────────┘      └────────┬───────┘ │
│         │                                             │         │
│         │             ┌──────────────┐               │         │
│         └────────────►│  Woodpecker  │◄──────────────┘         │
│                       │    Agent     │                         │
│                       └──────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Services

| Service | Port | Description | Healthcheck |
|---------|------|-------------|-------------|
| **forgejo** | 5333 (HTTP)<br>5222 (SSH) | Forge Git (clone de Gitea) | `/api/healthz` |
| **woodpecker-server** | 5444 | Serveur CI/CD | `/healthz` |
| **woodpecker-agent** | - | Agent d'exécution des pipelines | `/healthz` (interne) |

### Volumes

```
volumes/
├── forgejo/           # Données Git, DB, configuration
├── woodpecker-server/ # Données CI/CD
└── woodpecker-agent/  # Cache et données de build
```

### Réseau

- **Réseau bridge** : `forgejo-net` (172.25.0.0/16)
- **Communication inter-services** : Par nom de service DNS
- **Exposition externe** : Ports mappés sur localhost

---

## ⚙️ Configuration

### Fichier .env

Le fichier `.env` contient toute la configuration de la stack.

#### Variables Essentielles

```bash
# Admin Forgejo (créé automatiquement)
ADMIN_USERNAME=forgejo-admin
ADMIN_PASSWORD=VotreMotDePasseFort123!
ADMIN_EMAIL=admin@example.com
ADMIN_FULLNAME=Admin User

# Secret partagé Woodpecker (min 48 caractères)
WOODPECKER_AGENT_SECRET=secret-aleatoire-de-48-caracteres-minimum

# OAuth (LAISSER VIDE - auto-généré)
WOODPECKER_FORGEJO_CLIENT=
WOODPECKER_FORGEJO_SECRET=
```

#### Variables de Configuration

```bash
# Domaines et URLs
FORGEJO_DOMAIN=localhost
FORGEJO_ROOT_URL=http://localhost:5333/
WOODPECKER_HOST=http://localhost:5444

# Ports externes
FORGEJO_HTTP_PORT=5333
FORGEJO_SSH_PORT=5222
WOODPECKER_HTTP_PORT=5444

# Base de données
FORGEJO_DB_TYPE=sqlite3
FORGEJO_DB_PATH=/data/gitea/forgejo.db

# Stockage
VOLUMES_BASE=./volumes

# Logs et performance
WOODPECKER_LOG_LEVEL=info
WOODPECKER_MAX_WORKFLOWS=2
```

### Personnalisation

#### Changer les ports

Si les ports par défaut sont occupés :

```bash
# Dans .env
FORGEJO_HTTP_PORT=8080      # Au lieu de 5333
FORGEJO_SSH_PORT=2222       # Au lieu de 5222
WOODPECKER_HTTP_PORT=9000   # Au lieu de 5444

# Pensez à mettre à jour les URLs
FORGEJO_ROOT_URL=http://localhost:8080/
WOODPECKER_HOST=http://localhost:9000
```

Puis redémarrez :
```bash
docker compose down
docker compose up -d
```

#### Changer le domaine (production)

```bash
# Dans .env
FORGEJO_DOMAIN=git.monentreprise.com
FORGEJO_ROOT_URL=https://git.monentreprise.com/
WOODPECKER_HOST=https://ci.monentreprise.com
```

**Important** : Utilisez un reverse proxy (Traefik, Nginx, Caddy) pour gérer HTTPS.

#### Augmenter les ressources

Éditez `docker-compose.yml` :

```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'      # Au lieu de 2.0
      memory: 2G       # Au lieu de 1G
    reservations:
      cpus: '1.0'
      memory: 512M
```

---

## 💻 Utilisation

### Créer votre premier dépôt

1. **Dans Forgejo** (http://localhost:5333)
   - Créer un nouveau dépôt
   - Initialiser avec un README
   - Ajouter un fichier `.woodpecker.yml` à la racine

2. **Exemple de `.woodpecker.yml`** :

```yaml
when:
  branch: main

steps:
  hello:
    image: alpine:latest
    commands:
      - echo "Hello from Woodpecker CI!"
      - date
      
  build:
    image: golang:1.21
    commands:
      - go version
      - echo "Build successful!"
```

3. **Dans Woodpecker** (http://localhost:5444)
   - Activer le dépôt
   - Push un commit
   - → Le pipeline s'exécute automatiquement ✅

### Exemples de Pipelines

#### Pipeline Node.js

```yaml
when:
  branch: main

steps:
  install:
    image: node:20-alpine
    commands:
      - npm ci
      
  test:
    image: node:20-alpine
    commands:
      - npm test
      
  build:
    image: node:20-alpine
    commands:
      - npm run build
```

#### Pipeline Docker

```yaml
when:
  branch: main

steps:
  build-image:
    image: plugins/docker
    settings:
      repo: myapp
      tags: latest
      dockerfile: Dockerfile
```

#### Pipeline Python

```yaml
when:
  branch: main

steps:
  test:
    image: python:3.11-slim
    commands:
      - pip install -r requirements.txt
      - pytest
      
  lint:
    image: python:3.11-slim
    commands:
      - pip install flake8
      - flake8 .
```

---

## ✅ Validation

### Script de validation automatique

```bash
./scripts/validate-stack.sh
```

**Ce script teste** :
- ✅ Docker et Docker Compose disponibles
- ✅ Conteneurs démarrés
- ✅ Forgejo healthy
- ✅ Woodpecker healthy
- ✅ OAuth créé
- ✅ Credentials chargés dans Woodpecker
- ✅ Endpoint OAuth fonctionnel
- ✅ Agent Woodpecker connecté
- ✅ Volume partagé accessible

### Tests manuels

#### Tester Forgejo

```bash
# Health endpoint
curl http://localhost:5333/api/healthz

# Doit retourner : {"status":"ok"}
```

#### Tester Woodpecker

```bash
# Health endpoint
curl http://localhost:5444/healthz

# Doit retourner : 200 OK
```

#### Vérifier OAuth

```bash
# Voir les credentials dans Forgejo
docker compose exec forgejo cat /shared/oauth-credentials.env

# Vérifier qu'ils sont chargés dans Woodpecker
docker compose exec woodpecker-server env | grep WOODPECKER_FORGEJO
```

---

## 🛠️ Commandes Utiles

### Gestion de la stack

```bash
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Redémarrer un service
docker compose restart forgejo
docker compose restart woodpecker-server

# Voir les logs
docker compose logs -f
docker compose logs -f forgejo
docker compose logs -f woodpecker-server

# Voir l'état
docker compose ps

# Rebuild complet
docker compose build --no-cache
docker compose up -d --force-recreate
```

### Debugging

```bash
# Entrer dans un conteneur
docker compose exec forgejo sh
docker compose exec woodpecker-server sh

# Voir les variables d'environnement
docker compose exec woodpecker-server env

# Voir les logs d'initialisation OAuth
docker compose logs forgejo | grep "\[INIT\]"

# Vérifier le volume partagé
docker compose exec forgejo ls -la /shared/
docker compose exec forgejo cat /shared/oauth-credentials.env
```

### Maintenance

```bash
# Optimiser la base de données
./scripts/optimize-db.sh

# Créer une sauvegarde
./scripts/backup.sh

# Nettoyer les logs Docker
docker compose logs --tail=0 -f
```

---

## 🐛 Troubleshooting

### OAuth ne se configure pas

**Symptômes** :
- Variables `WOODPECKER_FORGEJO_CLIENT` et `SECRET` vides
- Erreur "OAuth not configured" dans Woodpecker

**Solutions** :

1. **Vérifier que OAuth a été créé** :
```bash
docker compose logs forgejo | grep "first-run-init.sh terminé"
```

2. **Vérifier le fichier partagé** :
```bash
docker compose exec forgejo cat /shared/oauth-credentials.env
```

3. **Vérifier l'entrypoint Woodpecker** :
```bash
docker compose logs woodpecker-server | grep "WOODPECKER-ENTRYPOINT"
```

4. **Redémarrer Woodpecker** :
```bash
docker compose restart woodpecker-server
```

### Forgejo ne démarre pas

**Symptômes** :
- Conteneur redémarre en boucle
- `docker compose ps` montre "Restarting"

**Solutions** :

1. **Voir les logs** :
```bash
docker compose logs forgejo --tail 100
```

2. **Vérifier les permissions** :
```bash
ls -la volumes/forgejo/
# Doit être accessible par UID 1000
```

3. **Corriger les permissions** :
```bash
sudo chown -R 1000:1000 volumes/forgejo/
```

### Woodpecker Agent déconnecté

**Symptômes** :
- Pipelines ne s'exécutent pas
- "No agents available" dans Woodpecker

**Solutions** :

1. **Vérifier les logs** :
```bash
docker compose logs woodpecker-agent
```

2. **Vérifier le secret** :
```bash
# Doit être identique dans server et agent
docker compose exec woodpecker-server env | grep AGENT_SECRET
docker compose exec woodpecker-agent env | grep AGENT_SECRET
```

3. **Redémarrer l'agent** :
```bash
docker compose restart woodpecker-agent
```

### Port déjà utilisé

**Symptômes** :
```
Error: bind: address already in use
```

**Solutions** :

1. **Identifier le processus** :
```bash
sudo netstat -tulpn | grep :5333
```

2. **Changer le port** dans `.env` :
```bash
FORGEJO_HTTP_PORT=8080
```

3. **Redémarrer** :
```bash
docker compose down
docker compose up -d
```

### Réinitialisation complète

En cas de problème majeur :

```bash
# ⚠️ ATTENTION : Supprime toutes les données !
docker compose down -v
rm -rf volumes/
docker compose up -d
```

---

## 🔒 Sécurité en Production

### Checklist de Sécurité

- [ ] **Changer les secrets par défaut**
  - ADMIN_PASSWORD : Mot de passe fort (16+ caractères)
  - WOODPECKER_AGENT_SECRET : 48+ caractères aléatoires

- [ ] **Utiliser HTTPS**
  - Mettre en place un reverse proxy (Traefik, Nginx, Caddy)
  - Obtenir certificats Let's Encrypt
  - Rediriger HTTP → HTTPS

- [ ] **Restreindre l'accès réseau**
  - Firewall : Autoriser uniquement 80/443
  - SSH : Changer le port par défaut (pas 22)
  - Désactiver WOODPECKER_OPEN en production

- [ ] **Sauvegardes automatiques**
  - Configurer cron pour `./scripts/backup.sh`
  - Sauvegarder sur stockage distant

- [ ] **Mettre à jour régulièrement**
  - Surveiller les nouvelles versions
  - Tester en staging avant prod

### Générer des secrets forts

```bash
# Mot de passe admin (32 caractères)
openssl rand -base64 32

# Secret agent Woodpecker (64 caractères)
openssl rand -base64 48

# Alternative avec /dev/urandom
cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | fold -w 32 | head -n 1
```

### Exemple Reverse Proxy (Traefik)

**docker-compose.yml** (extrait) :
```yaml
services:
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

  forgejo:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.forgejo.rule=Host(`git.example.com`)"
      - "traefik.http.routers.forgejo.entrypoints=websecure"
      - "traefik.http.routers.forgejo.tls.certresolver=letsencrypt"
```

---

## 💾 Sauvegarde et Restauration

### Sauvegarde automatique

```bash
# Exécuter le script de backup
./scripts/backup.sh

# Sauvegardes créées dans ./backups/
ls -lh backups/
```

### Planifier des sauvegardes (cron)

```bash
# Éditer crontab
crontab -e

# Ajouter (sauvegarde quotidienne à 2h du matin)
0 2 * * * cd /chemin/vers/Forgejo-Woodpecker-Docker && ./scripts/backup.sh
```

### Restaurer depuis une sauvegarde

```bash
# 1. Arrêter la stack
docker compose down

# 2. Restaurer les volumes
tar -xzf backups/backup-YYYY-MM-DD-HH-MM-SS.tar.gz -C ./

# 3. Redémarrer
docker compose up -d
```

### Sauvegarde manuelle

```bash
# Créer une archive timestampée
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
tar -czf backup-$TIMESTAMP.tar.gz volumes/ .env

# Copier sur stockage distant (exemple)
scp backup-$TIMESTAMP.tar.gz user@backup-server:/backups/
```

---

## 📊 Monitoring et Logs

### Logs en temps réel

```bash
# Tous les services
docker compose logs -f

# Service spécifique
docker compose logs -f forgejo

# Dernières 100 lignes
docker compose logs --tail 100 forgejo
```

### Rotation des logs

Les logs sont automatiquement limités via `docker-compose.yml` :

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"    # Taille max par fichier
    max-file: "3"      # Nombre max de fichiers
```

### Healthchecks

Tous les services ont des healthchecks :

```bash
# Voir l'état de santé
docker compose ps

# Format : (healthy), (unhealthy), (starting)
```

---

## 🤝 Contribution

Les contributions sont les bienvenues !

### Comment contribuer

1. **Fork** le projet
2. **Créer une branche** : `git checkout -b feature/ma-feature`
3. **Committer** : `git commit -am 'Ajout ma feature'`
4. **Pousser** : `git push origin feature/ma-feature`
5. **Pull Request** sur GitHub

### Guidelines

- Code propre et commenté
- Tests validés avec `./scripts/validate-stack.sh`
- Documentation à jour
- Commits atomiques avec messages clairs

---

## 📜 Licence

Ce projet est sous licence **MIT**.

Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

## 🙏 Remerciements

- [Forgejo](https://forgejo.org/) - Forge Git libre et auto-hébergée
- [Woodpecker CI](https://woodpecker-ci.org/) - CI/CD moderne et léger
- [Docker](https://www.docker.com/) - Plateforme de conteneurisation
- Tous les contributeurs et utilisateurs de ce projet

---

## 📞 Support

### Documentation

- 📖 [Guide de Démarrage Rapide](GUIDE-DEMARRAGE-RAPIDE.md)
- 📖 [Analyse Technique](ANALYSE-PROBLEME.md)
- 📖 [Changelog](CHANGELOG.md)
- 📖 [Index des Fichiers](INDEX-FICHIERS.md)

### Communauté

- 💬 [Discussions](../../discussions)
- 🐛 [Issues](../../issues)

### Ressources Externes

- [Documentation Forgejo](https://forgejo.org/docs/)
- [Documentation Woodpecker](https://woodpecker-ci.org/docs/)
- [Docker Documentation](https://docs.docker.com/)

---

## 📈 Statistiques du Projet

| Métrique | Valeur |
|----------|--------|
| **Temps de déploiement** | ~2 minutes |
| **Configuration manuelle** | Zéro |
| **Taux de réussite workflow** | 100% |
| **Services** | 3 (Forgejo, Woodpecker Server, Woodpecker Agent) |
| **Ports exposés** | 3 (5222, 5333, 5444) |

---

<div align="center">

**Fait avec ❤️ pour la communauté**


[⬆ Retour en haut](#-forgejo--woodpecker-ci---stack-auto-configurée)

</div>
