
# 🚀 Forgejo + Woodpecker CI - Stack DevOps Légère

## Description

Stack DevOps légère et auto-hébergée combinant **Forgejo 14** (gestion de code source) et **Woodpecker CI** (intégration continue), déployée via Docker et Docker Compose. Configuration simple et minimaliste pour un usage personnel ou petites équipes.

## ✨ Caractéristiques

- **Légèreté** : Image Alpine pour Woodpecker, SQLite pour Forgejo
- **Simplicité** : Configuration centralisée dans `.env`, pas de base de données externe
- **Intégration** : Connexion native Forgejo ↔ Woodpecker
- **Maintenance** : Optimisation automatique de la base de données

## 📋 Prérequis

| Prérequis | Version minimum |
|-----------|-----------------|
| Docker Engine | 20.10+ |
| Docker Compose | v2 |
| RAM | 2 Go |
| Ports libres | 5333, 5222, 5444 |

## 🔧 Installation

```bash
# Cloner le repository
git clone https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker

# Configurer les variables d'environnement
nano .env

# Lancer la stack
docker compose up -d --build
```

## 🌐 Accès aux services

| Service | URL | Port |
|---------|-----|------|
| Interface Forgejo | http://localhost:5333 | 5333 |
| Interface Woodpecker | http://localhost:5444 | 5444 |
| SSH Git | ssh://git@localhost:5222 | 5222 |

## 📁 Structure du projet

```
Forgejo-Woodpecker-Docker/
├── docker-compose.yml      # Orchestration des services
├── Dockerfile.forgejo      # Forgejo 14 avec cron
├── .env                    # Toutes les variables d'environnement
├── scripts/
│   ├── optimize-db.sh      # Optimisation SQLite
│   └── entrypoint-cron.sh  # Point d'entrée avec cron
├── backups/                # Répertoire de sauvegardes
└── logs/                   # Logs applicatifs
```

## 🔒 Configuration du fichier .env

Toutes les variables de configuration sont centralisées dans le fichier `.env`. Copier le fichier `.env.example` (ou renommer `.env`) et adapter les valeurs.

### Fichier .env complet

```env
# ========================
# 🔐 SECRETS (obligatoire)
# ========================
WOODPECKER_AGENT_SECRET=votre_secret_aleatoire_ici

# ========================
# 🌍 CONFIGURATION RÉSEAU
# ========================
# Ports exposés
FORGEJO_HTTP_PORT=5333
WOODPECKER_HTTP_PORT=5444
SSH_PORT=5222

# Domaines et URLs
FORGEJO_DOMAIN=localhost
FORGEJO_ROOT_URL=http://localhost:5333
FORGEJO_SSH_DOMAIN=localhost
WOODPECKER_HOST=http://localhost:5444

# ========================
# 🗄️ BASE DE DONNÉES
# ========================
FORGEJO_DB_TYPE=sqlite3
FORGEJO_DB_PATH=/data/forgejo.db

# ========================
# 🔗 INTÉGRATION FORGEJO ↔ WOODPECKER
# ========================
# URL interne de Forgejo (communication entre conteneurs)
WOODPECKER_FORGEJO_URL=http://forgejo:3000

# ========================
# 🐙 OAUTH GITHUB (optionnel)
# ========================
WOODPECKER_GITHUB=true
WOODPECKER_GITHUB_CLIENT=
WOODPECKER_GITHUB_SECRET=

# ========================
# 🔑 OAUTH FORGEJO (recommandé)
# ========================
WOODPECKER_FORGEJO_CLIENT=
WOODPECKER_FORGEJO_SECRET=
```

### Détail des variables

#### Secrets (obligatoire)

| Variable | Description | Exemple |
|----------|-------------|---------|
| `WOODPECKER_AGENT_SECRET` | Secret de communication agent-serveur | `openssl rand -hex 32` |

#### Configuration réseau

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `FORGEJO_HTTP_PORT` | Port externe interface web Forgejo | `5333` |
| `WOODPECKER_HTTP_PORT` | Port externe interface Woodpecker | `5444` |
| `SSH_PORT` | Port SSH pour Git | `5222` |
| `FORGEJO_DOMAIN` | Domaine/accessibilité Forgejo | `localhost` |
| `FORGEJO_ROOT_URL` | URL complète d'accès à Forgejo | `http://localhost:5333` |
| `WOODPECKER_HOST` | URL d'accès à Woodpecker | `http://localhost:5444` |

#### Base de données

| Variable | Description | Valeur |
|----------|-------------|--------|
| `FORGEJO_DB_TYPE` | Type de base de données | `sqlite3` |
| `FORGEJO_DB_PATH` | Chemin du fichier SQLite | `/data/forgejo.db` |

#### Intégration

| Variable | Description | Valeur |
|----------|-------------|--------|
| `WOODPECKER_FORGEJO_URL` | URL interne (conteneur à conteneur) | `http://forgejo:3000` |

> **Note** : L'URL interne utilise le nom du service Docker (`forgejo`) comme hostname, permettant la communication entre conteneurs sur le même réseau Docker.

#### OAuth Forgejo (recommandé)

Permet l'authentification via Forgejo pour accéder à Woodpecker.

**Création dans Forgejo :**
1. http://localhost:5333 → **Paramètres** → **Applications**
2. **Nouvelle OAuth App** :
   - Nom : `Woodpecker CI`
   - URL de redirection : `http://localhost:5444/authorize`
3. Copier le **Client ID** et **Client Secret** dans `.env`

```env
WOODPECKER_FORGEJO_CLIENT=VotreClientID
WOODPECKER_FORGEJO_SECRET=VotreClientSecret
```

#### OAuth GitHub (optionnel)

Pour utiliser GitHub comme fournisseur d'authentification.

**Création sur GitHub :**
1. GitHub → **Settings** → **Developer settings** → **OAuth Apps**
2. **New OAuth App** :
   - Homepage URL : `http://localhost:5444`
   - Authorization callback URL : `http://localhost:5444/authorize`

```env
WOODPECKER_GITHUB=true
WOODPECKER_GITHUB_CLIENT=VotreGitHubClientID
WOODPECKER_GITHUB_SECRET=VotreGitHubClientSecret
```

## 🚦 Première utilisation

1. **Configurer `.env`** avec toutes les variables ci-dessus
2. **Lancer la stack** :
   ```bash
   docker compose up -d --build
   ```
3. **Accéder à Forgejo** : http://localhost:5333
4. **Créer le compte** administrateur (premier utilisateur)
5. **Créer l'OAuth App** dans Forgejo (section précédente)
6. **Redémarrer Woodpecker** :
   ```bash
   docker compose restart woodpecker-server
   ```
7. **Se connecter** à http://localhost:5444 via Forgejo

## 🛠️ Commandes

```bash
# Logs en temps réel
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f woodpecker-server

# Redémarrer un service
docker compose restart forgejo
docker compose restart woodpecker-server
docker compose restart woodpecker-agent

# Arrêter la stack
docker compose down

# Supprimer les données (Attention : perte de données)
docker compose down -v
```

## 📅 Maintenance

- **Optimisation DB** : Chaque dimanche à 3h00 (automatique via cron)
- **Logs** : Répertoire `./logs/`
- **Sauvegardes** : À configurer selon vos besoins

## 📄 Licence

MIT