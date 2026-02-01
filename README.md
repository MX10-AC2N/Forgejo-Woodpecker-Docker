## 🚀 Installation Ultra-Rapide (Zero-Config)

```bash
# 1. Cloner le repository
git clone https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker

# 2. Copier le fichier d'environnement
cp .env.example .env

# 3. (OPTIONNEL) Modifier le mot de passe admin
nano .env  # Changer ADMIN_PASSWORD

# 4. Démarrer la stack - C'EST TOUT ! 🎉
docker compose up -d --build

# 5. Attendre 3-5 minutes le temps de l'initialisation
docker compose logs -f

# 6. Accéder aux services
# Forgejo: http://localhost:5333
# Woodpecker: http://localhost:5444 (OAuth auto-configuré ✅)
✨ Configuration OAuth 100% Automatique
Plus besoin de configurer OAuth manuellement !
Lors du premier démarrage :
✅ Forgejo crée automatiquement le compte admin
✅ Forgejo crée automatiquement l'application OAuth
✅ Les credentials sont partagés avec Woodpecker via volume Docker
✅ Woodpecker démarre avec OAuth pré-configuré
Résultat : Cliquez simplement sur "Login" dans Woodpecker et vous êtes connecté !
🔍 Vérification
# Vérifier que tout fonctionne
curl -I http://localhost:5444/authorize
# Doit retourner une redirection 302/303 vers Forgejo ✅

# Voir les logs d'initialisation
docker compose logs forgejo | grep -A 5 "OAuth créé"
docker compose logs woodpecker-server | grep "OAuth"
🔧 Si OAuth ne se configure pas automatiquement
Cas rare : Si Woodpecker démarre avant que Forgejo ait créé l'OAuth :
# Attendre 2-3 minutes puis redémarrer Woodpecker
docker compose restart woodpecker-server

# Ou utiliser le script de secours
./scripts/configure-oauth.sh
docker compose restart woodpecker-server