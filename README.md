# Forgejo + Woodpecker CI - Stack DevOps Personnelle

## Description du projet

Ce repository propose une stack DevOps complète et auto-hébergée, combinant **Forgejo**, une solution de gestion de code source fork de Gitea, et **Woodpecker CI**, un système d'intégration et de déploiement continu moderne. L'ensemble est déployé via Docker et Docker Compose, offrant une solution clés en main pour les développeurs et les équipes souhaitant掌控 leur infrastructure de développement sans dépendre de services tiers.

Cette configuration est particulièrement adaptée aux développeurs individuels, aux petites équipes ou aux organisations qui valorisent la souveraineté de leurs données. En utilisant des conteneurs Docker, le projet garantit une installation reproductible et isolée, facilitant ainsi les tests, les migrations et la maintenance. L'intégration native entre Forgejo et Woodpecker CI permet une expérience fluide, depuis le push de code jusqu'au déploiement automatisé, le tout restant sous votre contrôle total.

Le projet inclut des scripts de maintenance automatisés pour optimiser les performances de la base de données SQLite de Forgejo, ainsi qu'une configuration prête à l'emploi pour l'authentification OAuth avec GitHub ou Forgejo lui-même. Cette approche modulaire permet une personnalisation aisée selon vos besoins spécifiques, que ce soit pour un usage personnel ou pour une infrastructure plus complexe.

## Fonctionnalités principales

### Forgejo - Gestion de code source

Forgejo constitue le cœur de votre infrastructure de développement, offrant une interface web intuitive et des fonctionnalités complètes de gestion de repositories Git. Le service prend en charge la création de repositories publics et privés, la gestion des organisations et des équipes, ainsi que le suivi des issues et des pull requests. L'interface utilisateur est traduite en plusieurs langues et propose des fonctionnalités sociales comme les stars, les watches et les forks, encourageant la collaboration au sein des équipes de développement.

Le système de permissions granulaires de Forgejo permet de contrôler précisément l'accès aux repositories selon les rôles des utilisateurs. Vous pouvez configurer des permissions de lecture, d'écriture et d'administration au niveau des équipes et des repositories individuels. Cette flexibilité s'avère particulièrement utile pour les projets open source ou les organisations avec des équipes interdépendantes.

La configuration incluse utilise SQLite comme base de données, simplifiant considérablement le déploiement et la maintenance pour un usage personnel ou de petite échelle. Cette choix technique élimine la nécessité de configurer un serveur de base de données externe tout en offrant des performances suffisantes pour la plupart des cas d'usage.

### Woodpecker CI - Intégration et déploiement continus

Woodpecker CI complète parfaitement Forgejo en fournissant un système d'intégration continue puissant et moderne. Son architecture basée sur des pipelines déclaratifs en YAML permet de définir des workflows complexes pour les tests, la construction et le déploiement d'applications. Le système supporte nativement l'exécution de conteneurs Docker pour les steps de pipeline, offrant une isolation complète et une reproductibilité optimale des builds.

L'agent Woodpecker est configuré pour avoir accès au socket Docker de l'hôte, permettant la création et la gestion de conteneurs pendant les pipelines. Cette capacité ouvre la possibilité de tester des applications dans des environnements isolés, de construire des images Docker personnalisées ou de déployer des services via Docker Compose directement depuis vos pipelines.

L'interface web de Woodpecker affiche en temps réel l'état des builds, les logs détaillés de chaque step et l'historique des exécutions. Les notifications peuvent être configurées pour informer les équipes des succès ou échecs de builds via différents canaux, intégrant parfaitement la boucle de feedback dans votre processus de développement.

### Scripts de maintenance automatisés

Le projet inclut deux scripts de maintenance essentiels pour garantir la stabilité et les performances de votre infrastructure. Le script d'optimisation de la base de données exécute des opérations VACUUM et REINDEX sur la base SQLite de Forgejo, réduisant la taille du fichier de base de données et améliorant les performances des requêtes. Ces opérations sont planifiées via cron pour s'exécuter automatiquement chaque dimanche à 3h du matin, période généralement calme pour la plupart des installations.

Le script d'entrée point avec cron intégré permet de lancer Forgejo avec le service cron actif en arrière-plan. Cette approche garantit que les tâches planifiées s'exécutent correctement sans interférer avec le processus principal de Forgejo. Les logs de maintenance sont conservés dans le répertoire `/data/log` pour faciliter le suivi et le débogage éventuel.

## Prérequis système

Avant de déployer cette stack, assurez-vous que votre système hôte dispose des prérequis suivants. Docker Engine version 20.10 ou supérieure doit être installé et en cours d'exécution. Vous pouvez vérifier l'installation avec la commande `docker --version` et `docker-compose --version`. Pour Docker Compose V2, la commande serait `docker compose version`.

Un minimum de 2 Go de RAM est recommandé pour le fonctionnement fluide des trois conteneurs, bien que 4 Go soit preferable pour des projets plus importants ou lors de l'exécution simultanée de plusieurs builds CI. L'espace disque dépendra de la taille de vos repositories et de l'historique des builds, mais un minimum de 10 Go d'espace libre est conseillé pour commencer.

Les ports suivants doivent être disponibles et non utilisés par d'autres services sur votre machine : le port 5333 pour l'interface web de Forgejo, le port 5222 pour les connexions SSH Git, et le port 5444 pour l'interface web de Woodpecker CI. Si ces ports sont déjà utilisés, vous devrez les modifier dans le fichier `docker-compose.yml` et ajuster les URLs de configuration en conséquence.

## Installation et configuration initiale

### Cloner le repository

La première étape consiste à cloner ce repository sur votre machine locale ou votre serveur. Ouvrez un terminal et exécutez la commande suivante pour copier les fichiers dans un répertoire de votre choix. Il est recommandé de placer le projet dans un répertoire dédié, par exemple `/opt` ou un autre emplacement selon vos conventions de nomenclature.

```bash
git clone https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker
```

Une fois le repository cloné, vous constaterez la présence de plusieurs fichiers et répertoires essentiels. Le fichier `docker-compose.yml` orchestre l'ensemble des services, le `Dockerfile.forgejo` définit l'image personnalisée de Forgejo, le fichier `.env` contient les variables de configuration sensibles, et le répertoire `scripts/` héberge les scripts de maintenance.

### Configurer les variables d'environnement

Avant de lancer les conteneurs, vous devez configurer le fichier `.env` avec vos propres valeurs. Ce fichier contient les secrets nécessaires au fonctionnement de Woodpecker CI et les identifiants OAuth optionnels. Éditez le fichier avec votre éditeur de texte favori et remplacez les valeurs par défaut.

La variable `WOODPECKER_AGENT_SECRET` est particulièrement importante car elle assure la communication sécurisée entre l'agent et le serveur Woodpecker. Choisissez une chaîne de caractères aléatoire et suffisamment longue, idéalement supérieure à 32 caractères. Vous pouvez générer un secret sécurisé avec la commande `openssl rand -hex 32`.

Pour l'authentification OAuth avec GitHub, créez une OAuth App dans les paramètres de votre compte GitHub. La callback URL doit pointer vers votre instance Woodpecker, par exemple `http://localhost:5444/authorize` pour une installation locale. Renseignez ensuite les variables `WOODPECKER_GITHUB_CLIENT` et `WOODPECKER_GITHUB_SECRET` avec les identifiants obtenus.

Si vous préférez utiliser l'authentification native Forgejo, configurez une OAuth App directement dans Forgejo après son démarrage, accessible à l'adresse `http://localhost:5333/user/settings/applications`. La callback URL sera `http://localhost:5444/authorize`. Cette approche est recommandée pour une intégration plus simple et une meilleure expérience utilisateur.

### Lancer la stack Docker

Avec les variables d'environnement configurées, vous pouvez maintenant démarrer l'ensemble de la stack. La commande suivante construit l'image personnalisée de Forgejo et lance les trois conteneurs en arrière-plan. L'option `-d` detached mode` permet de récupérer la main du terminal immédiatement.

```bash
docker compose up -d --build
```

Les premières fois, le téléchargement des images Docker et la construction de l'image Forgejo peuvent prendre quelques minutes selon votre connexion internet et les performances de votre machine. Vous pouvez suivre la progression des conteneurs avec la commande `docker compose logs -f`. Appuyez sur Ctrl+C pour arrêter l'affichage des logs sans arrêter les conteneurs.

Une fois les conteneurs démarrés, vérifiez leur état avec `docker compose ps`. Les trois services doivent apparaître avec le statut « Up ». Si un service présente un statut « Exited » ou « Restarting », consultez les logs correspondants pour identifier le problème.

## Accès aux services

### Interface web de Forgejo

L'interface web de Forgejo est accessible à l'adresse `http://localhost:5333`. Lors du premier accès, vous serez guidé à travers un assistant de configuration initiale. Pour une installation personnelle, les paramètres par défaut conviennent généralement, avec la base de données SQLite déjà préconfigurée.

Créez votre compte utilisateur administrateur lors de cette première configuration. Le premier utilisateur enregistré devient automatiquement administrateur du système. Notez bien vos identifiants car ils vous permettront d'accéder à toutes les fonctionnalités d'administration, incluant la gestion des utilisateurs, la configuration des paramètres système et la création d'OAuth Apps pour Woodpecker.

Une fois connecté, explorez les paramètres de votre profil et configurez votre clé SSH si vous souhaitez utiliser les connexions SSH pour Git. La clé publique doit être ajoutée dans vos paramètres Forgejo, et votre configuration Git locale doit utiliser l'URL SSH correspondante, pointant vers `ssh://git@localhost:5222/`.

### Interface web de Woodpecker CI

L'interface de Woodpecker CI est disponible à `http://localhost:5444`. Si vous avez configuré l'authentification OAuth, vous serez redirigé vers la page de connexion de Forgejo ou GitHub selon votre choix. Après authentification, Woodpecker synchronisera automatiquement vos repositories depuis Forgejo.

Pour activer Woodpecker sur un repository, accédez aux paramètres de ce repository dans Forgejo et activez le webhook Woodpecker. Vous devrez peut-être ajouter le repository manuellement dans Woodpecker si la synchronisation automatique ne fonctionne pas. Dans l'interface Woodpecker, naviguez vers la page du repository et activez-le via le bouton approprié.

La configuration des pipelines s'effectue via un fichier `.woodpecker.yml` à la racine de chaque repository. Ce fichier définit les étapes de votre pipeline, les conditions d'exécution et les variables d'environnement. Woodpecker propose une syntaxe YAML intuitive avec support des conditions, des matrices de build et des dépendances entre étapes.

### Connexions Git

Pour cloner ou push vers vos repositories, utilisez les URLs appropriées selon votre méthode de connexion. Pour les connexions HTTP, l'URL suit le format `http://localhost:5333/<utilisateur>/<repository>.git`. Les connexions SSH utilisent `ssh://git@localhost:5222/<utilisateur>/<repository>.git`.

Si vous rencontrez des erreurs de certificat SSL lors des connexions HTTP, assurez-vous que les URLs de configuration dans Forgejo correspondent exactement à l'adresse que vous utilisez pour accéder à l'interface web. Les navigateurs modernes peuvent bloquer les requêtes mixtes ou les requêtes vers des domaines non sécurisés.

## Structure du projet

Le projet est organisé selon une structure claire facilitant la compréhension et la maintenance. Le fichier `docker-compose.yml` à la racine définit l'ensemble des services, réseaux et volumes Docker. Cette configuration centralisée permet de gérer le cycle de vie complet de l'infrastructure avec des commandes simples.

Le `Dockerfile.forgejo` étend l'image officielle de Forgejo avec les outils de maintenance nécessaires. L'utilisation de l'image de base `codeberg.org/forgejo/forgejo:14` garantit la stabilité tout en bénéficiant des dernières fonctionnalités de Forgejo. Les commandes RUN installent les paquets requis et préparent l'environnement d'exécution.

Le répertoire `scripts/` contient les scripts shell exécutés automatiquement par les conteneurs. Le script `optimize-db.sh` effectue les opérations de maintenance sur la base de données SQLite, tandis que `entrypoint-cron.sh` remplace le point d'entrée par défaut pour activer le service cron. Cette approche modulaire permet d'ajouter facilement de nouveaux scripts de maintenance si nécessaire.

Le fichier `.env` stocke les variables de configuration sensibles séparément du code source. Cette séparation facilite le partage du repository sans exposer les secrets, encourageant de bonnes pratiques de sécurité. Assurez-vous de ne jamais commiter ce fichier dans un repository public.

## Personnalisation avancée

### Modification des ports

Si les ports par défaut entrent en conflit avec d'autres services sur votre machine, vous pouvez les modifier dans le fichier `docker-compose.yml`. Les mappings de ports sont définis dans la section `ports` de chaque service, au format `"port_externe:port_interne"`. Après modification, redémarrez les conteneurs avec `docker compose up -d`.

Attention toutefois aux URLs de callback OAuth qui devront également être mises à jour. Les services OAuth externes comme GitHub utilisent ces URLs pour rediriger après authentification. Modifiez les paramètres de votre OAuth App en conséquence pour éviter les erreurs d'authentification.

### Ajout de services supplémentaires

Pour étendre votre stack DevOps, vous pouvez ajouter des services complémentaires via Docker Compose. Par exemple, vous pourriez ajouter un registry Docker privé avec Harbor, un système de monitoring avec Prometheus et Grafana, ou un gestionnaire de secrets comme Vault. Chaque nouveau service peut être intégré au réseau `forgejo-net` existant pour communiquer directement avec Forgejo et Woodpecker.

La modification du fichier `docker-compose.yml` pour ajouter des services suit la même syntaxe que les services existants. Utilisez des images officielles ou des Dockerfiles personnalisés selon vos besoins, et configurez les variables d'environnement et volumes appropriés. La documentation officielle de Docker Compose fournit des exemples détaillés pour les configurations courantes.

### Configuration avancée de Woodpecker

Woodpecker propose de nombreuses options de configuration avancées accessibles via les variables d'environnement. Vous pouvez activer des fonctionnalités comme les pipelines conditionnels, les plugins personnalisés ou l'intégration avec des services externes. La documentation officielle de Woodpecker détaille l'ensemble des options disponibles.

Pour les équipes distribuées ou les projets à forte charge, vous pouvez déployer plusieurs agents Woodpecker en parallèle. Chaque agent peut être configuré avec des capacités différentes ou des pools de ressources dédiés. Cette scalabilité horizontale permet d'adapter la puissance de calcul CI à vos besoins évolutifs.

## Maintenance et surveillance

### Surveillance des logs

La consultation régulière des logs permet d'identifier les problèmes potentiels avant qu'ils n'affectent le fonctionnement de vos services. Utilisez `docker compose logs forgejo`, `docker compose logs woodpecker-server` et `docker compose logs woodpecker-agent` pour consulter les logs de chaque service. L'option `-f` permet un suivi en temps réel.

Pour un debugging plus approfondi, augmentez le niveau de log dans la configuration de Forgejo et Woodpecker. Les logs détaillés peuvent révéler des problèmes de connexion, des erreurs de configuration OAuth ou des performances dégradées. Une fois le problème identifié et résolu, revenez au niveau de log standard pour éviter de saturer l'espace disque.

### Sauvegardes régulières

Bien que le projet inclue un script de maintenance pour la base de données, il est crucial de mettre en place une stratégie de sauvegarde complète. Sauvegardez régulièrement les volumes Docker `forgejo_data`, `woodpecker_server_data` et le répertoire `backups/` si vous l'utilisez.

Une approche simple consiste à utiliser des scripts de sauvegarde automatisés exécutés via cron sur l'hôte. Ces scripts peuvent archiver les volumes dans des fichiers compressés avec horodatage, puis transférer les sauvegardes vers un stockage externe ou un service cloud pour la redondance.

### Mise à jour des composants

Les technologies évoluent rapidement, et les mises à jour régulières sont essentielles pour la sécurité et les nouvelles fonctionnalités. Consultez régulièrement les release notes de Forgejo et Woodpecker pour identifier les mises à jour importantes. Les images Docker officielles sont taguées par version, facilitant la mise à jour.

Pour mettre à jour, modifiez les références d'image dans `docker-compose.yml` avec les nouvelles versions, puis exécutez `docker compose up -d`. Les données persistantes dans les volumes ne seront pas affectées par la mise à jour des images. Testez toujours les mises à jour dans un environnement de développement avant de les appliquer en production.

## Dépannage des problèmes courants

### Problèmes de connexion à la base de données

Si Forgejo ne démarre pas correctement, les logs peuvent indiquer des problèmes de base de données. Vérifiez que le volume `forgejo_data` est correctement montés et accessible en écriture. Les permissions des fichiers dans le volume peuvent parfois causer des problèmes après une mise à jour ou un redémarrage.

Pour les problèmes de corruption de la base SQLite, arrêtez les conteneurs, supprimez le fichier de base de données corrompu dans le volume, puis redémarrez Forgejo. Attention, cette opération supprimera toutes les données de la base. Utilisez cette solution en dernier recours et uniquement si vous n'avez pas de sauvegarde récente.

### Échecs d'authentification OAuth

Les erreurs OAuth sont généralement causées par des URLs de callback incorrectes ou des secrets mal configurés. Vérifiez que les URLs de callback dans vos applications OAuth correspondent exactement aux URLs d'accès à Woodpecker, y compris le protocole, le port et le chemin.

Les secrets OAuth dans le fichier `.env` doivent correspondre exactement à ceux configurés dans l'application OAuth externe. Un caractère supplémentaire ou un espace peut causer l'échec de l'authentification. Copiez-collez les valeurs directement pour éviter les erreurs de saisie.

### Build Woodpecker en échec

Les échecs de build peuvent avoir de nombreuses causes. Commencez par consulter les logs détaillés de Woodpeecker pour l'exécution concernée. Les erreurs courantes incluent des variables d'environnement manquantes, des images Docker non disponibles ou des timeouts de ressources.

Vérifiez que l'agent Woodpecker a bien accès au socket Docker de l'hôte et dispose des permissions nécessaires. Sur certaines configurations, des problèmes de permissions peuvent empêcher la création de conteneurs pendant les builds.

## Contribution et développement

Les contributions à ce projet sont bienvenues ! Que vous souhaitiez corriger un bug, améliorer la documentation ou proposer de nouvelles fonctionnalités, n'hésitez pas à ouvrir une issue ou une pull request. Le code est structuré de manière claire pour faciliter la compréhension et les modifications.

Pour les modifications importantes, créez d'abord une issue pour discuter de votre proposition. Cela évite le travail en double et permet d'aligner les contributions avec la vision du projet. Les pull requests doivent passer les checks automatisés et inclure une description détaillée des changements.

## Licence

Ce projet est distribué sous la licence MIT. Cette licence permissive vous permet d'utiliser, modifier et distribuer le code librement, même à des fins commerciales. La seule obligation est d'inclure la notice de copyright et la licence dans toute copie ou distribution substantielle du logiciel

-----