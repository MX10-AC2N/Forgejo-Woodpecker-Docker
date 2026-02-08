# 🚀 Forgejo + Woodpecker CI - Stack Optimisée

Stack complète d'intégration continue avec Forgejo (Git) et Woodpecker CI, entièrement conteneurisée avec Docker Compose.

## ✨ Fonctionnalités

- ✅ **Configuration OAuth automatique** : Les credentials OAuth sont générés automatiquement au premier démarrage
- ✅ **Chargement automatique** : Woodpecker charge les credentials depuis un volume partagé
- ✅ **Validation complète** : Script de validation pour tester tous les composants
- ✅ **Healthchecks optimisés** : Surveillance de la santé de tous les services
- ✅ **Logs structurés** : Logs clairs avec préfixes pour faciliter le debugging
- ✅ **Tests CI/CD** : Workflow GitHub Actions pour validation automatique
- ✅ **Documentation** : README complet avec toutes les étapes

## 📋 Prérequis

- Docker Engine 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum
- 10GB d'espace disque

## 🚀 Démarrage rapide

### 1. Cloner le projet

```bash
git clone <votre-repo>
cd Forgejo-Woodpecker-Docker
```

### 2. Créer le fichier .env

```bash
cp .env.example .env
# Éditez .env et changez au minimum :
# - ADMIN_PASSWORD (mot de passe admin)
# - WOODPECKER_AGENT_SECRET (secret agent, min 48 caractères)
```

### 3. Lancer la stack

```bash
# Build et démarrage
docker compose up -d

# Suivre les logs
docker compose logs -f
```

### 4. Attendre l'initialisation (2-3 minutes)

```bash
# Le script first-run-init.sh va :
# 1. Installer Forgejo
# 2. Créer l'utilisateur admin
# 3. Générer l'application OAuth
# 4. Sauvegarder les credentials dans /shared/oauth-credentials.env

# Vérifier les logs d'initialisation
docker compose logs forgejo | grep "\[INIT\]"
```

### 5. Valider la stack

```bash
# Lancer le script de validation
chmod +x scripts/validate-stack.sh
./scripts/validate-stack.sh
```

### 6. Accéder aux interfaces

- **Forgejo** : http://localhost:5333
  - Login : `forgejo-admin` (ou votre ADMIN_USERNAME)
  - Password : celui défini dans ADMIN_PASSWORD

- **Woodpecker CI** : http://localhost:5444
  - Cliquer sur "Login" → redirection vers Forgejo
  - Autoriser l'application OAuth

## 📂 Structure du projet

```
.
├── docker-compose.yml              # Configuration principale
├── .env                            # Variables d'environnement
├── Dockerfile.forgejo              # Image Forgejo personnalisée
├── Dockerfile.woodpecker-server    # Image Woodpecker avec entrypoint
├── scripts/
│   ├── first-run-init.sh          # Initialisation auto OAuth (dans Forgejo)
│   ├── entrypoint-woodpecker-server.sh  # Entrypoint Woodpecker
│   ├── validate-stack.sh          # Script de validation
│   └── configure-oauth.sh         # Config manuelle OAuth (si besoin)
├── .github/
│   └── workflows/
│       └── deploy-and-test-stack.yml  # CI/CD validation
└── volumes/                        # Données persistantes (créé auto)
    ├── forgejo/
    ├── woodpecker-server/
    └── woodpecker-agent/
```

## 🔐 Configuration OAuth automatique

### Comment ça fonctionne ?

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Forgejo   │         │  Volume partagé  │         │   Woodpecker    │
│             │         │   /shared/       │         │     Server      │
└──────┬──────┘         └────────┬─────────┘         └────────┬────────┘
       │                         │                            │
       │ 1. Créer OAuth app      │                            │
       │ (first-run-init.sh)     │                            │
       ├────────────────────────►│                            │
       │                         │                            │
       │ 2. Sauvegarder          │                            │
       │ oauth-credentials.env   │                            │
       │                         │◄───────────────────────────┤
       │                         │  3. Charger credentials    │
       │                         │  (entrypoint au démarrage) │
       │                         │                            │
```

### Flux détaillé

1. **Au premier démarrage de Forgejo** :
   - Le script `first-run-init.sh` s'exécute en background
   - Il attend que Forgejo soit prêt
   - Il installe Forgejo via l'API
   - Il crée une application OAuth via l'API Forgejo
   - Il sauvegarde les credentials dans `/shared/oauth-credentials.env`

2. **Au démarrage de Woodpecker Server** :
   - L'entrypoint personnalisé vérifie si `/shared/oauth-credentials.env` existe
   - Si oui, il charge les variables `WOODPECKER_FORGEJO_CLIENT` et `WOODPECKER_FORGEJO_SECRET`
   - Il lance Woodpecker avec ces credentials

3. **Résultat** :
   - OAuth est automatiquement configuré
   - Pas besoin de redémarrage manuel
   - Pas besoin de configuration manuelle

## 🛠️ Commandes utiles

### Gestion de la stack

```bash
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Redémarrer un service
docker compose restart woodpecker-server

# Voir les logs
docker compose logs -f
docker compose logs -f forgejo
docker compose logs -f woodpecker-server

# Voir l'état
docker compose ps

# Reconstruire les images
docker compose build --no-cache
docker compose up -d --force-recreate
```

### Debug OAuth

```bash
# Vérifier que le fichier OAuth existe
docker compose exec forgejo ls -lah /shared/
docker compose exec forgejo cat /shared/oauth-credentials.env

# Vérifier que Woodpecker a chargé les credentials
docker compose exec woodpecker-server env | grep WOODPECKER_FORGEJO

# Extraire les credentials des logs
docker compose logs forgejo | grep "WOODPECKER_FORGEJO_CLIENT\|WOODPECKER_FORGEJO_SECRET"

# Valider la stack complète
./scripts/validate-stack.sh
```

### Réinitialisation complète

```bash
# ATTENTION : Cela supprime toutes les données !
docker compose down -v
rm -rf volumes/
docker compose up -d
```

## 🐛 Résolution de problèmes

### ❌ Woodpecker ne se connecte pas à Forgejo

**Cause** : Les credentials OAuth ne sont pas chargés

**Solution** :
```bash
# 1. Vérifier que OAuth a été créé dans Forgejo
docker compose logs forgejo | grep "first-run-init.sh terminé"

# 2. Vérifier le fichier partagé
docker compose exec forgejo cat /shared/oauth-credentials.env

# 3. Redémarrer Woodpecker pour recharger
docker compose restart woodpecker-server

# 4. Valider
docker compose exec woodpecker-server env | grep WOODPECKER_FORGEJO
```

### ❌ "first-run-init.sh n'a pas confirmé"

**Cause** : Le script d'initialisation prend plus de 3 minutes

**Solution** :
```bash
# Vérifier les logs complets
docker compose logs forgejo | grep "\[INIT\]"

# Si le script est bloqué, vérifier :
# 1. Forgejo est bien healthy
docker compose ps

# 2. Les credentials admin sont corrects
grep ADMIN .env
```

### ❌ OAuth redirect 404 ou 500

**Cause** : Mauvaise URL de redirect configurée

**Solution** :
```bash
# Vérifier la configuration
docker compose exec woodpecker-server env | grep WOODPECKER

# Vérifier que WOODPECKER_HOST correspond à l'URL externe
# Par défaut : http://localhost:5444
```

### ❌ Woodpecker Agent non connecté

**Cause** : Secret agent différent entre server et agent

**Solution** :
```bash
# Vérifier que WOODPECKER_AGENT_SECRET est identique
docker compose exec woodpecker-server env | grep AGENT_SECRET
docker compose exec woodpecker-agent env | grep AGENT_SECRET

# Doit être minimum 48 caractères
```

## 🔒 Sécurité

### En production

⚠️ **NE PAS utiliser les valeurs par défaut !**

Changez au minimum :
- `ADMIN_PASSWORD` : mot de passe fort
- `WOODPECKER_AGENT_SECRET` : minimum 48 caractères aléatoires
- Activer HTTPS avec un reverse proxy (Traefik, Nginx, Caddy)
- Utiliser des secrets Docker ou variables d'environnement chiffrées

### Génération de secrets

```bash
# Générer un secret de 64 caractères
openssl rand -base64 48

# Ou avec /dev/urandom
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
```

## 📊 Métriques et monitoring

### Healthchecks

Tous les services ont des healthchecks :
- **Forgejo** : `http://localhost:5333/api/healthz`
- **Woodpecker Server** : `http://localhost:5444/healthz`
- **Woodpecker Agent** : `http://localhost:3000/healthz` (interne)

### Vérification rapide

```bash
# Statut de tous les healthchecks
docker compose ps

# Tester manuellement
curl http://localhost:5333/api/healthz
curl http://localhost:5444/healthz
```

## 🧪 Tests CI/CD

Le projet inclut un workflow GitHub Actions qui :
1. Build la stack
2. Démarre les services
3. Attend que OAuth soit configuré
4. Valide tous les endpoints
5. Teste la connexion OAuth

Pour lancer les tests localement :
```bash
# Avec act (GitHub Actions localement)
act -j test-stack

# Ou manuellement
docker compose up -d
./scripts/validate-stack.sh
```

## 📝 Variables d'environnement

### Variables principales

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `FORGEJO_DOMAIN` | Domaine Forgejo | `localhost` | Non |
| `FORGEJO_HTTP_PORT` | Port HTTP Forgejo | `5333` | Non |
| `FORGEJO_ROOT_URL` | URL racine Forgejo | `http://localhost:5333/` | Non |
| `WOODPECKER_HOST` | URL publique Woodpecker | `http://localhost:5444` | Oui |
| `WOODPECKER_HTTP_PORT` | Port Woodpecker | `5444` | Non |
| `WOODPECKER_AGENT_SECRET` | Secret agent (48+ chars) | - | **Oui** |
| `ADMIN_USERNAME` | Login admin | `forgejo-admin` | Non |
| `ADMIN_PASSWORD` | Mot de passe admin | - | **Oui** |
| `ADMIN_EMAIL` | Email admin | `admin@ci.local` | Non |

### Variables OAuth (auto-générées)

Ces variables sont générées automatiquement, **ne les définissez pas manuellement** :
- `WOODPECKER_FORGEJO_CLIENT`
- `WOODPECKER_FORGEJO_SECRET`

Si vous devez les définir manuellement (cas avancé), consultez `scripts/configure-oauth.sh`.

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Fork le projet
2. Créez une branche : `git checkout -b feature/ma-feature`
3. Committez : `git commit -am 'Ajout ma feature'`
4. Pushez : `git push origin feature/ma-feature`
5. Ouvrez une Pull Request

## 📜 Licence

Ce projet est sous licence MIT.

## 🙏 Remerciements

- [Forgejo](https://forgejo.org/) - Git forge auto-hébergé
- [Woodpecker CI](https://woodpecker-ci.org/) - CI/CD léger et moderne
- [Docker](https://www.docker.com/) - Conteneurisation

## 📞 Support

- 📖 [Documentation Forgejo](https://forgejo.org/docs/)
- 📖 [Documentation Woodpecker](https://woodpecker-ci.org/docs/)
- 🐛 [Issues](../../issues)
- 💬 [Discussions](../../discussions)

