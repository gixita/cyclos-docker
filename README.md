# cyclos-docker
Deployment of Cyclos with proxy and monitoring using docker-compose.

Déploiement d'un serveur Cyclos pour les payements électroniques des monnaies complémentaires.
Toutes les ASBL n'ont pas en leur sein les compétences nécessaires pour déployer l'application Cyclos de manière professionnelle et sécurisée.
Ce repository a pour but de fournir une solution de déployement la plus simple possible afin qu'elle soit accessible à toutes ASBL.

Ces scripts de déployement ont été réalisés en s'inspirant majoritairement d'autres implémentations. Je remercie chaleureusement ces personnes du travail incroyable qu'ils ont accompli.
Mettre la liste de repository.

La solution est déployée sur un serveur linux (Ubuntu server) à l'aide de container Docker afin de faciliter la maintenance et les mises à jour.
La solution est composée de :
- un serveur proxy nginx pour la gestion des routes et les certificats Let's Encrypt.
- nginx-gen pour générer les fichier de configuration de nginx.
- le module nginx pour Let's Encrypt
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

Déploiement en local
La solution peut être déployée localement afin de paramétriser l'outil qui sera ensuite migré (facilement) sur le serveur de production de l'ASBL.

Etape 1 : Modifier le fichier /etc/hosts afin d'ajouter les différents chemins qui seront utilisés par l'application en local.
En production, nous n'utiliserons que deux chemins (ebanking et monitoring).
Vous pouvez remplacer "domain.com" par le domaine de votre ASBL (ex: mon-asbl.test) et ajouter ces valeurs au fichier /etc/hosts. 
De préférence, ne pas utiliser le nom de domaine de votre ASBL, car sinon vous ne pourrez plus y avoir accès de votre PC.
127.0.0.1       ebanking.domain.com
127.0.0.1       monitoring.domain.com
127.0.0.1       prometheus.domain.com
127.0.0.1       cadvisor.domain.com
127.0.0.1       node-exporter.domain.com
127.0.0.1       alertmanager.domain.com

Ensuite vider le cache du DNS local par la commande suivante :
dscacheutil -flushcache

Renommer le fichier .env.sample en .env
Modifier ensuite ce fichier .env de variable d'environnement qui sera utilisé par Docker.
La génération du mot de passe de la base de donnée devrait être fait avec la commande suivante :
openssl rand -base64 32
Les adresses en local doivent être les mêmes que celles utilisées dans le fichier /etc/hosts

# To be changed by each MLC
CYCLOS_DB_USER=db-username
CYCLOS_DB_PASSWORD=db-password
CYCLOS_VIRTUAL_HOST=ebanking.domain.com
HTTPS_MAIL=me@e-mail.com
GRAFANA_VIRTUAL_HOST=monitoring.domain.com
# End of to be changed by each MLC

## Only for localhost ##
PROMETHEUS_VIRTUAL_HOST=prometheus.domain.com
NODEEXPORTER_VIRTUAL_HOST=node-exporter.domain.com
ALERTMANAGER_VIRTUAL_HOST=alertmanager.domain.com
CADVISOR_VIRTUAL_HOST=cadvisor.domain.com
## End of only for localhost ##

Afin d'être alerté d'un problème avec le site web, il faut modifier le fichier de configuration de alertmanager.
Dans le cas présent, les alertes sont envoyées sur un channel Slack mais peuvent également être envoyées par mail. Voir le lien suivant pour faire cette modification (digital ocean).

Renommer le fichier ./alertmanager/config.yml.sample en ./alertmanager/config.yml et modifier le fichier ./alertmanager/config.yml avec vos paramètres Slack.
Un tutoriel explicant comment gérérer l'url d'api pour Slack peut être trouvé ici.

Il faut maintenant modifier le fichier de configuration de grafana pour afficher les résultats du monitoring.
Il faut renommer le fichier ./grafana/config.monitoring.sample en config.monitoring et modifier le fichier.
Utiliser un mot passe difficle, comme précédement en le générant à l'aide la commande openssl.

GF_SECURITY_ADMIN_PASSWORD=foobar
GF_USERS_ALLOW_SIGN_UP=false
GF_SERVER_ROOT_URL=http://monitoring.domain.com

Renommer le fichier prometheus.yml.sample en prometheus.yml se trouvant dans le répertoire prometheus.
Mettre l'url de votre site web qui sera en production dans le jobname "nginx".
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

Renommer alert.rules.sample en alert.rules dans le répertoire prometheus.
Indiquer l'URL de votre site web en production.
- name: cyclos
  rules:
  - alert: cyclos_down
    expr: probe_success{instance="https://ebanking.your-real-website.com",job="nginx"} == 0
    for: 1s
    labels:
      severity: critical
    annotations:
      summary: "cyclos is down - intervention required"


Il est temps maintenant d'installer Cyclos et les différents composants mentionnés ci-dessus.
Vous pouvez dans la racine du folder, utiliser la commande :
sh install-cyclos.sh
L'installation prendra un peu moins de 10 min, le temps d'un petit café.

Lorsque l'installation est terminée, vous pouvez utiliser la commande suivante pour voir si tous les containers sont actifs.

Docker ps 

Vous devriez avoir les containers suivants. Si certains sont manquants, il faudra vérifier que vous n'avez pas fait une faute de frappe en écrivant les variables d'environnement.
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

Les logs d'un container sont accessible via la commande 
docker logs <nom-du-container>

Se connecter à Grafana avec le login "admin" et mot de passe choisi.
Ajouter dans les datasources, la source prometheus.
Dans les dashboard, importer l'id #179.


Pour éteindre l'application, il suffit de faire 
sh stop-all.sh
Et si quelque chose c'est mal passé durant une extinction, vous pouvez fermer tous les containers actifs en ajoutant l'argument "force"
sh stop-all.sh

Pour redémarrer l'application Cyclos et tous les composant, utiliser la commande:
sh start-all.sh

Si après avoir détecter que dans les logs de Cyclos une erreur critique est apparue, vous pouvez redémarrer Cyclos uniquement par la commande
sh restart-cyclos.sh

Faire un backup manuel de la base de données de l'application Cyclos. La base de donnée doit être au moins active.
sh manual-backup-cyclos.sh

Par défaut les containers sont stateless, donc après le redémarrage d'un container, les données ont disparu, ce qui n'est pas pratique dans notre cas.
Différents dossiers sont montés dans la racine de ce projet dont par exemple db-data qui contient la base de données de Cyclos.
Les backups plannifiés sont stockés dans le répertoire db-backups.

Voilà, il est maintenant temps de commencer à paramètrer la solution Cyclos pour votre ASBL. Bon amusement.

Déploiement sur le serveur de production
Maintenant que votre solution est paramétrée et correspond exactement aux besoins de citoyens de votre région, nous allons migrer la solution Cyclos vers le serveur de production.
Toutes les actions doivent être réalisée en ssh sur le serveur de production.
La sécurisation du serveur de production doit avoir été faite tel que décrit au début de cette page.
La première étape est d'ajouter dans les DNS de votre hébergeur les deux sous-domaines suivants :
ebanking.domain.com
monitoring.domain.com
Qui pointent vers l'adresse IP du serveur sur lequel vous souhaitez installer l'application Cyclos en production.

Vous devez dans le répertoire de départ de votre user /home, cloner ce repository et uploader vos fichiers de configurations que vous avez modifié précédement.

Afin d'activer le HTTPS, il y a deux fichiers de plus à modifier : 
cyclos.yml
monitoring.yml

Il faut décommenter les lignes suivantes partout pour activer Let's Encrypt et sécuriser le site.
- LETSENCRYPT_HOST=${CYCLOS_VIRTUAL_HOST:-ebanking.domain.com}
- LETSENCRYPT_EMAIL=${HTTPS_MAIL:-me@example.com}

Mettre la base donnée paramétrée en local sur le serveur de production.
Faire un backup de la base de donnée locale avec la commande à lancer en local.
sh manual-backup-cyclos.sh
Un fichier compressé de backup de la base de donnée a été créé, ce fichier doit être décompressé et le fichier sql doit être copié dans le répertoire ./restoredb du serveur de production.
Veillez à ce que ce soit le seul fichier du répertoire. Sinon un message d'erreur vous empêchera de continuer pour des raisons de sécurité.

Sur le serveur de production dans le dossier de l'application, lancer
sh restoredb-cyclos.sh database-filename.sql

Vérifier que le container s'est bien éteind par la commande 
docker ps
Vous ne devriez pas voir apparaître de container cyclos-restore-db ni aucun autre container correspondant à l'application.
Relancer l'application Cyclos
sh start-all.sh

Tester intensivement votre plateforme Cyclos