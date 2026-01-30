# Forgejo with Woodpecker
#   Docker install

Ce projet permet de déployer facilement une stack **Forgejo** et **Woodpecker CI** avec Docker. Il est conçu pour faciliter l'intégration continue avec Forgejo (une alternative à GitHub) et Woodpecker CI. Ce README couvre la création d'un fichier `.env`, le déploiement avec Docker et la configuration de la synchronisation GitHub avec Forgejo.

---

## 📝 Fichier `.env` à créer

Créez un fichier `.env` dans le même répertoire que ce `README.md` et ajoutez-y les variables suivantes (remplacez les valeurs entre `< >` par vos informations spécifiques) :

#=== SECRETS CRITIQUES (Générez-les avec `openssl rand -base64 24`) ===
FORGEJO_JWT_SECRET=<votre_secret_forgejo_très_long>
WOODPECKER_AGENT_SECRET=<votre_secret_woodpecker_très_long>

#=== APPLICATION OAUTH FORGEJO (Pour connecter Woodpecker à Forgejo) ===
# 1. Allez dans Forgejo (http://localhost:3000) > "Paramètres" > "Applications"
# 2. Créez une application OAuth2 :
#    - Nom : "Woodpecker CI"
#    - URI de redirection : http://localhost:8000/authorize
# 3. Copiez l'ID Client et le Secret ici :
WOODPECKER_FORGEJO_CLIENT=<client_id_de_votre_app_forgejo>
WOODPECKER_FORGEJO_SECRET=<client_secret_de_votre_app_forgejo>

#=== APPLICATION OAUTH GITHUB (Optionnel - Pour la synchro directe) ===
# 1. Créez une OAuth App sur GitHub : https://github.com/settings/developers
# 2. Homepage URL : http://localhost:3000
# 3. Authorization callback : http://localhost:8000/authorize
# 4. Copiez l'ID Client et le Secret ici :
WOODPECKER_GITHUB_CLIENT=<votre_client_id_github>
WOODPECKER_GITHUB_SECRET=<votre_client_secret_github>

#=== CONFIGURATION VARIABLE ===
WOODPECKER_HOST=http://localhost:8000


---

##🚀 Instructions de déploiement

#1. Préparation

Commencez par créer le répertoire du projet et les fichiers nécessaires :
```bash
mkdir forgejo-woodpecker && cd forgejo-woodpecker
touch docker-compose.yml .env
```
# Copiez-collez le contenu ci-dessus dans chaque fichier

2. Générez les secrets et complétez le fichier .env

Exécutez la commande suivante pour générer des secrets sécurisés :
```bash
openssl rand -base64 24
```
# Utilisez la sortie pour remplir FORGEJO_JWT_SECRET et WOODPECKER_AGENT_SECRET dans le fichier .env

3. Démarrez la stack

Démarrez les services avec Docker Compose :
```bash
docker-compose up -d
```
4. Configuration initiale

Forgejo

1. Accédez à Forgejo : http://localhost:3000


2. Complétez l'installation (choisissez SQLite3 comme base de données).


3. Créez un utilisateur administrateur.


4. Créez l'application OAuth2 :

Nom : "Woodpecker CI"

URI de redirection : http://localhost:8000/authorize



5. Copiez l'ID Client et le Secret de l'application OAuth2, puis mettez à jour votre fichier .env.



Woodpecker CI

1. Accédez à Woodpecker CI : http://localhost:8000


2. À la première connexion, choisissez "Se connecter avec Forgejo".


3. Autorisez l'application OAuth et vos dépôts Forgejo apparaîtront dans Woodpecker CI.




---

🔧 Synchronisation GitHub avec Forgejo (Optionnel)

Si vous souhaitez synchroniser vos dépôts GitHub avec Forgejo, suivez ces étapes :

1. Créez une application OAuth sur GitHub : https://github.com/settings/developers


2. Configurez l'URL de la page d'accueil : http://localhost:3000


3. Configurez le callback d'autorisation : http://localhost:8000/authorize


4. Copiez l'ID Client et le Secret dans votre fichier .env sous la section WOODPECKER_GITHUB_CLIENT et WOODPECKER_GITHUB_SECRET.



Ajouter un miroir de dépôt

1. Dans un projet Forgejo, allez dans Paramètres > Miroir du dépôt.


2. Ajoutez l'URL du dépôt GitHub à synchroniser : https://github.com/utilisateur/depot.git.


3. Pour l'authentification, utilisez un Personal Access Token GitHub (avec la permission repo).




---

💡 Bonnes pratiques additionnelles

Vérification des logs : Après le démarrage des services, consultez les logs pour vérifier que tout fonctionne correctement :

docker-compose logs -f

Sauvegarde : N'oubliez pas de sauvegarder régulièrement les volumes Docker (par exemple, forgejo_data).

Mise à jour : Pour mettre à jour les images Docker, modifiez le tag (par exemple, :1.21.9) dans le fichier docker-compose.yml, puis exécutez :

docker-compose pull && docker-compose up -d



---

Bonne installation et utilisation de Forgejo et Woodpecker CI ! 🚀
