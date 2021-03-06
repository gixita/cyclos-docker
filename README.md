# cyclos-docker
Deployment of [Cyclos](https://www.cyclos.org/) with proxy, automatic backups and monitoring using docker-compose.

Déploiement d'un serveur Cyclos pour les paiements électroniques des monnaies locales complémentaires.
Ce repository a pour but de fournir une solution de déployement la plus simple possible afin qu'elle soit accessible à toutes ASBL de gestion de MLC.

Ces scripts de déployements ont été réalisés en s'inspirant majoritairement d'autres implémentations. Je remercie ces personnes du travail qu'ils ont accompli. Vous pouvez trouver ci-dessous les liens vers leurs repository GitHub.
- https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion
- https://github.com/prodrigestivill/docker-postgres-backup-local
- https://github.com/vegasbrianc/prometheus
- https://github.com/davidshimjs/qrcodejs

La solution est déployée sur un serveur linux (Ubuntu server 18.04) à l'aide de Docker afin de faciliter la maintenance et les mises à jour.
La solution est composée de :
- un serveur proxy nginx pour la gestion des routes et les certificats Let's Encrypt.
- nginx-gen pour générer les fichiers de configuration de Nginx.
- le module Nginx pour Let's Encrypt
- la base de donnée postgres de Cyclos
- l'application java Cyclos
- un système de backup automatique sur calendrier (réglé ici pour faire une sauvegarde toutes les heures)
- un système de monitoring de ressource et fonctionnement du site comprennant 
    - prometheus
    - cadvisor
    - node-exporter
    - blackbox-exporter
    - alertmanager
- l'outil de dashboarding grafana pour visualiser les données du monitoring.

## Sécuriser votre server
La première étape est de sécuriser votre serveur, vous pouvez suivre les [instructions fournies par OVH](https://docs.ovh.com/fr/vps/conseils-securisation-vps/) pour les premières étapes.
Mettre à jour le serveur via les commandes suivantes.
```bash
apt-get update
apt-get upgrade
```
Ajouter un nouvel utilisateur non administrateur (non root)
```bash
adduser votreusername
```
Choisissez un mot de passe fort avec la fonction suivante.
```bash
openssl rand -base64 32
```
L'étape suivante est de sécuriser l'accès via une clé EDCSA (meilleur qu'une clé RSA). Localement sur votre PC personnel.
```bash
ssh-keygen -t ecdsa -b 521
```
Copier la clé EDCSA sur votre serveur avec la commande suivante en remplacant user par le nom d'utilisateur choisi pour le compte non administrateur de la machine et host comme adresse IP du serveur.
```bash
ssh-copy-id -i ~/.ssh/id_ecdsa user@host
```
Modifier le fichier `/etc/ssh/sshd_config` sur le serveur et établir la configuration suivante. Ceci obligera la connexion SSH a utiliser la clé EDCSA et empêchera de se connecter en temps que root directement.
```bash
PasswordAuthentication no
PubkeyAuthentication yes
RSAAuthentication yes
PermitRootLogin no
```
Répéter les étapes de création d'un nouvel utilisateur "backupuser" pour fournir la clé EDCSA à un autre utilisateur de backup (à stocker dans le coffre de votre monnaie locale).
Ajouter un nouvel utilisateur non administrateur (non root)
```bash
su root
adduser backupuser
```
```bash
ssh-keygen -t ecdsa -b 521
```
Avec comme nom de fichier `backupuser`. Copier le contenu de `backupuser.pub` dans le fichier `/home/backupuser/.ssh/authorized_keys` sur le serveur. Déconnectez vous et tester la connection au serveur via le compte `backupuser`.

Il faut maintenant stocker les clés privées EDCSA de manière sûre. La meilleur solution reste le papier. Vous pouvez utiliser un QR code pour récupérer plus facilement la clé privée. Vous pouvez utiliser l'outil se trouvant dans le dossier `QR-Code` de ce repository. Le code original de cet outil peut être trouvé sur https://github.com/davidshimjs/qrcodejs
Imprimer la page HTML contenant la clé EDCSA et le QR-Code. Faites le pour les deux utilisateurs.

N'oubliez pas d'ajouter les règles Firewall via l'interface de votre cloud provider.

## Installation de Docker CE
Le procédure d'installation peut être trouvée sur [le site Docker](https://docs.docker.com/install/linux/docker-ce/ubuntu/)
Installer `docker-compose`
```bash
sudo apt  install docker-compose
```
Afin de pouvoir utiliser Docker sans utiliser la commande `sudo`, il faut ajouter votre user au groupe `docker`.
```bash
sudo gpasswd -a $USER docker
```


## Déploiement en local
La solution peut être déployée localement afin de paramétriser l'outil qui sera ensuite migré (facilement) sur le serveur de production de l'ASBL.

Modifier votre fichier `/etc/hosts` afin d'ajouter les différents chemins qui seront utilisés par l'application en local.
En production, nous n'utiliserons que deux chemins (`ebanking` et `monitoring`).
```bash
127.0.0.1       monitoring.localhost
127.0.0.1       prometheus.localhost
127.0.0.1       cadvisor.localhost
127.0.0.1       node-exporter.localhost
127.0.0.1       alertmanager.localhost
```

Ensuite vider le cache du DNS local par la commande suivante :
```bash
dscacheutil -flushcache
```

Renommer le fichier `./params/.env.sample` en `./params/.env`
Modifier ensuite ce fichier `.env` de variable d'environnement qui sera utilisé par Docker.
La génération du mot de passe de la base de donnée devrait être fait avec la commande suivante :
```bash
openssl rand -base64 32
```
Les adresses en local doivent être les mêmes que celles utilisées dans le fichier `/etc/hosts`

```bash
# To be changed by each MLC
CYCLOS_DB_USER=db-username
CYCLOS_DB_PASSWORD=db-password
CYCLOS_VIRTUAL_HOST=ebanking.localhost
HTTPS_MAIL=me@e-mail.com
GRAFANA_VIRTUAL_HOST=monitoring.localhost
# End of to be changed by each MLC

## Only for localhost ##
PROMETHEUS_VIRTUAL_HOST=prometheus.localhost
NODEEXPORTER_VIRTUAL_HOST=node-exporter.localhost
ALERTMANAGER_VIRTUAL_HOST=alertmanager.localhost
CADVISOR_VIRTUAL_HOST=cadvisor.localhost
## End of only for localhost ##
```


Afin d'être alerté d'un problème avec le site web, il faut modifier le fichier de configuration de alertmanager.
Dans le cas présent, les alertes sont envoyées sur un channel Slack mais peuvent également être envoyées par mail. Voir le lien suivant pour faire cette modification ([digital ocean](https://www.digitalocean.com/community/tutorials/how-to-use-alertmanager-and-blackbox-exporter-to-monitor-your-web-server-on-ubuntu-16-04)).

Renommer le fichier `./params/config.yml.sample` en `./params/config.yml` et modifier le fichier `./params/config.yml` avec vos paramètres Slack.
Création d'un incoming webhook sur Slack : 
- Ouvrir dans le browser votre team Slack `https://<your-slack-team>.slack.com/apps`
- Cliquer sur Créer en haut à droite
- Choisir Incoming Web Hooks link sous Send Messages
- Cliquer sur  "incoming webhook integration"
- Choisir le channel
- Cliquer sur Add Incoming WebHooks integration

Il faut maintenant modifier le fichier de configuration de grafana pour afficher les résultats du monitoring.
Il faut renommer le fichier `./params/config.monitoring.sample` en `./params/config.monitoring` et modifier le fichier.
Utiliser un mot passe difficle, comme précédement en le générant à l'aide la commande openssl.

```bash
GF_SECURITY_ADMIN_PASSWORD=foobar
GF_USERS_ALLOW_SIGN_UP=false
GF_SERVER_ROOT_URL=http://monitoring.domain.com
```

Renommer le fichier `./params/prometheus.yml.sample` en `./params/prometheus.yml`.
Mettre l'url de votre site web qui sera en production dans le jobname `nginx`.
```bash
- job_name: 'nginx'
    metrics_path: /probe
    scrape_interval: 300s
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://ebanking.your-real-website.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115
```

Renommer `./params/alert.rules.sample` en `./params/alert.rules`.
Indiquer l'URL de votre site web en production.
```bash
- name: cyclos
  rules:
  - alert: cyclos_down
    expr: probe_success{instance="https://ebanking.your-real-website.com",job="nginx"} == 0
    for: 1s
    labels:
      severity: critical
    annotations:
      summary: "cyclos is down - intervention required"
```

Appliquer les paramètres avec la commande suivante.
```bash
sh apply-params.sh
source .env # juste pour être sûr
docker network create $NETWORK
```
A chaque fois que vous modifiez des paramètres se trouvant dans le dossier `./params`, il est nécessaire de répèter la commande d'application des paramètres.

Il est temps maintenant d'installer Cyclos et les différents composants mentionnés ci-dessus.
Vous pouvez dans la racine du folder, utiliser la commande :
```bash
sh install-cyclos.sh
```
L'installation prendra un peu moins de 10 min, le temps d'un petit café.

Lorsque l'installation est terminée, vous pouvez utiliser la commande suivante pour voir si tous les containers sont actifs.

```bash
docker ps 
```

Vous devriez voir les containers suivants. Si certains sont manquants, il faudra vérifier que vous n'avez pas fait une faute de frappe en écrivant les variables d'environnement.
```bash
nginx-letsencrypt
nginx-gen
nginx-web
cyclos-db
pgbackups
cyclos-app
blackbox
alertmanager
node-exporter
cadvisor
prometheus
grafana
```

Les logs d'un container sont accessible via la commande 
```bash
docker logs <nom-du-container>
```

Se connecter à Grafana avec le login "admin" et mot de passe choisi.
Ajouter dans les datasources, la source prometheus.
Dans les dashboard, importer l'id `#179`.


Pour éteindre l'application, il suffit de faire 
```bash
sh stop-all.sh
```
Et si quelque chose c'est mal passé durant une extinction, vous pouvez fermer tous les containers actifs en ajoutant l'argument "force"
```bash
sh stop-all.sh force
```

Pour redémarrer l'application Cyclos et tous les composants, utiliser la commande:
```bash
sh start-all.sh
```

Si après avoir détecter que dans les logs de Cyclos une erreur critique est apparue, vous pouvez redémarrer Cyclos uniquement par la commande
```bash
sh restart-cyclos.sh
```

Faire un backup manuel de la base de données de l'application Cyclos. La base de donnée (container cyclos-db) doit être active.
```bash
sh manual-backup-cyclos.sh
```

Par défaut les containers sont stateless, donc après le redémarrage d'un container, les données ont disparu, ce qui n'est pas pratique dans notre cas.
Différents dossiers sont montés dans la racine de ce projet dont par exemple `db-data` qui contient la base de données de Cyclos.
Les backups plannifiés sont stockés dans le répertoire `db-backups`.

Voilà, il est maintenant temps de commencer à paramètrer la solution Cyclos pour votre ASBL. Bon amusement.

## Déploiement sur le serveur
Maintenant que votre solution est paramétrée et correspond exactement à vos besoins, nous allons migrer la solution Cyclos vers le serveur.
Pour vous connecter en SSH sur le serveur, il est nécessaire de vous connecter avec un certificat de sécurité.
La première étape est d'ajouter dans les DNS de votre hébergeur les deux sous-domaines suivants :
```bash
ebanking.domain.com
monitoring.domain.com
```
Qui pointent vers l'adresse IP du serveur sur lequel vous souhaitez installer l'application Cyclos en production.

Vous devez dans le répertoire de votre choix, cloner ce repository et uploader vos fichiers de configuration que vous avez modifié précédement.

Il faut décommenter les lignes suivantes dans les fichiers `cyclos.yml` et `monitoring.yml` pour activer Let's Encrypt et obtenir de l'HTTPS.
```bash
- LETSENCRYPT_HOST=${CYCLOS_VIRTUAL_HOST:-ebanking.domain.com}
- LETSENCRYPT_EMAIL=${HTTPS_MAIL:-me@example.com}
```

Mettre la base donnée paramétrée en local sur le serveur de production.
La première étape est d'aller dans le menu d'administration général de Cyclos, ensuite configuration et indiquer l'adresse principale comme étant l'adresse vers laquelle le site va être migré.
Faire un backup de la base de donnée locale avec la commande (à lancer en local).
```bash
sh manual-backup-cyclos.sh
```
Remettre dans la configuration locale, l'adresse principale précédement changée.
Un fichier compressé de backup de la base de donnée a été créé, ce fichier doit être décompressé et le fichier sql être copié dans le répertoire `./restoredb` du serveur de production.

## Remplacement de la base de données
Sur le serveur de production dans le dossier de l'application.
Eteindre tous les containeurs sur le serveur
```bash
sh stop-all.sh force
```
Effacer le dossier de la base de données (seulement si vous avez effectué un backup précédement).
```bash
sudo rm -rf db-data
```
Lancer un containeur temporaire pour faire un rétablissement de la base de données.
```bash
docker run -d \
    --name=cyclos-restore-db \
    --hostname=cyclos-db \
    -v $(pwd)/db-data:/var/lib/postgresql/data \
    -v $(pwd)/restoredb:/restoredb \
    -e POSTGRES_DB=${CYCLOS_DB_NAME} \
    -e POSTGRES_USER=${CYCLOS_DB_USER} \
    -e POSTGRES_PASSWORD=${CYCLOS_DB_PASSWORD} \
    cyclos/db
```
Attendre au moins une minute, puis entrer dans le containeur en ligne de commande.
```bash
docker exec -it cyclos-restore-db /bin/bash
```
Lancer le rétablissement de la base données.
ATTENTION cette action est irréversible.
```bash
psql -U VotreUserAdminDB -d NomDeLaDB -f /restoredb/NomDuFichierDump.sql
```
Eteindre tous les containeurs.
```bash
sh stop-all.sh force
```

Vérifier que le container s'est bien éteint par la commande 
```bash
docker ps
```
Vous ne devriez pas voir apparaître de container `cyclos-restore-db` ni aucun autre container correspondant à l'application.
Relancer l'application Cyclos
```bash
sh start-all.sh
```

Tester intensivement votre plateforme Cyclos

## Modification dans l'interface d'administration si l'application est en production
Lorsque vous ferez des modifications de votre plateforme, n'oubliez pas de faire un backup manuel avant de faire la moindre modification par la commande.
```bash
sh manual-backup-cyclos.sh
```

## Remarques concernant la paramétrisation
J'ai quelques fois fait des modifications qui m'ont obligé à restaurer la DB dans une version antérieure. Ceci n'a pas pour vocation d'être exhaustif mais uniquement de vous conscientiser sur les dangers d'une mauvaise paramétrisation en phase de production. Voici quelques unes de mes erreurs:
- Utiliser le même login pour le compte global que pour l'administrateur réseau
  Conséquence : je n'avais plus accès au compte global
- Définir le code PIN comme code de confirmation à la connection
  Impossible de se connecter avec le compte global car il n'avait pas de code PIN activé

Pour la configuration de l'envoie d'emails, si vous passez par OVH, vous pouvez utiliser la configuration suivante :
- Hôte : ssl0.ovh.net
- Port : 587
- Utilisateur : l'adresse mail utilisée pour envoyer vos mails
- Password : le mot de passe de la boîte mail
- Protocole de sécurité : STARTTLS

Vous pouvez modifier les traductions de l'interface web et mobile, je recommande de changer au moins les éléments suivants :
- Mobile > Accueil > searchUsers : Rechercher des prestataires
- Mobile > Utlisateurs > searchUser : Chercher un prestataire
- Mobile > Utlisateurs > heading : Prestataires
- Mobile > Géneral > next : Continuer
- Mobile > Marché > next : Continuer
- Mobile > Paiements > quickHint : Entrer le {0} du destinataire ou sélectionner une option ci-dessous

## Protocole à adopter en cas de problème sur la plateforme
Cette procédure ne devrait être envisagée qu'en cas de gros problème dont vous ne comprenez pas l'origine.
Attention de bien suivre le protocole.
Se connecter en temps qu'administrateur global de la plateforme. Modifier dans la configuration par défaut l'url principale du site en `http://localhost`. NE PAS SE DECONNECTER DE LA PLATEFORME.
Se connecter en SSH sur le serveur et lancer un backup manuel.
```bash
sh manual-backup-cyclos.sh
```
Sur l'interface administrateur, remettre l'adresse principale qui a été modifiée à sa valeur d'origine et enregister la configuration.
Ensuite éteindre l'application de paiement électronique.
```bash
sh stop-all.sh
```
A l'aide d'un logiciel FTP, copier l'ensemble des backups se trouvant dans le dossier `./db-backups`. Veillez également à copier l'ensemble de fichiers se trouvant dans le dossier `./params`
Vous pouvez maintenant investiguer le problème en déployant l'application localement.