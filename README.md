# cyclos-docker
Deployment of [Cyclos](https://www.cyclos.org/) with proxy, automatic backups and monitoring using docker-compose.

Déploiement d'un serveur Cyclos pour les payements électroniques des monnaies locales complémentaires.
Ce repository a pour but de fournir une solution de déployement la plus simple possible afin qu'elle soit accessible à toutes ASBL de gestion de MLC.

Ces scripts de déployements ont été réalisés en s'inspirant majoritairement d'autres implémentations. Je remercie ces personnes du travail qu'ils ont accompli. Vous pouvez trouver ci-dessous les liens vers leurs repository GitHub.
- https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion
- https://github.com/prodrigestivill/docker-postgres-backup-local
- https://github.com/vegasbrianc/prometheus

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

## Déploiement en local
La solution peut être déployée localement afin de paramétriser l'outil qui sera ensuite migré (facilement) sur le serveur de production de l'ASBL.

Modifier le fichier `/etc/hosts` afin d'ajouter les différents chemins qui seront utilisés par l'application en local.
En production, nous n'utiliserons que deux chemins (`ebanking` et `monitoring`).
Vous pouvez remplacer "domain.com" par le domaine de votre ASBL (ex: mon-asbl.test) et ajouter ces valeurs au fichier `/etc/hosts`. 
De préférence, ne pas utiliser le nom de domaine de votre ASBL, car sinon vous ne pourrez plus y avoir accès de votre PC.
```bash
127.0.0.1       ebanking.domain.com
127.0.0.1       monitoring.domain.com
127.0.0.1       prometheus.domain.com
127.0.0.1       cadvisor.domain.com
127.0.0.1       node-exporter.domain.com
127.0.0.1       alertmanager.domain.com
```

Ensuite vider le cache du DNS local par la commande suivante :
```bash
dscacheutil -flushcache
```

Renommer le fichier `.env.sample` en `.env`
Modifier ensuite ce fichier .env de variable d'environnement qui sera utilisé par Docker.
La génération du mot de passe de la base de donnée devrait être fait avec la commande suivante :
```bash
openssl rand -base64 32
```
Les adresses en local doivent être les mêmes que celles utilisées dans le fichier `/etc/hosts`

```bash
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
```

Afin d'être alerté d'un problème avec le site web, il faut modifier le fichier de configuration de alertmanager.
Dans le cas présent, les alertes sont envoyées sur un channel Slack mais peuvent également être envoyées par mail. Voir le lien suivant pour faire cette modification ([digital ocean](https://www.digitalocean.com/community/tutorials/how-to-use-alertmanager-and-blackbox-exporter-to-monitor-your-web-server-on-ubuntu-16-04)).

Renommer le fichier `./alertmanager/config.yml.sample` en `./alertmanager/config.yml` et modifier le fichier `./alertmanager/config.yml` avec vos paramètres Slack.
Création d'un incoming webhook sur Slack : 
- Open your slack team in your browser `https://<your-slack-team>.slack.com/apps`
- Click build in the upper right corner
- Choose Incoming Web Hooks link under Send Messages
- Click on the "incoming webhook integration" link
- Select which channel
- Click on Add Incoming WebHooks integration

Il faut maintenant modifier le fichier de configuration de grafana pour afficher les résultats du monitoring.
Il faut renommer le fichier `./grafana/config.monitoring.sample` en `config.monitoring` et modifier le fichier.
Utiliser un mot passe difficle, comme précédement en le générant à l'aide la commande openssl.

```bash
GF_SECURITY_ADMIN_PASSWORD=foobar
GF_USERS_ALLOW_SIGN_UP=false
GF_SERVER_ROOT_URL=http://monitoring.domain.com
```

Renommer le fichier `prometheus.yml.sample` en `prometheus.yml` se trouvant dans le répertoire prometheus.
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

Renommer `alert.rules.sample` en `alert.rules` dans le répertoire prometheus.
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

Vous devez dans le répertoire de départ de votre user `/home`, cloner ce repository et uploader vos fichiers de configuration que vous avez modifié précédement.

Afin d'activer le HTTPS, il y a deux fichiers de plus à modifier `cyclos.yml` et `monitoring.yml`.

Il faut décommenter les lignes suivantes partout pour activer Let's Encrypt et sécuriser le site.
```bash
- LETSENCRYPT_HOST=${CYCLOS_VIRTUAL_HOST:-ebanking.domain.com}
- LETSENCRYPT_EMAIL=${HTTPS_MAIL:-me@example.com}
```

Mettre la base donnée paramétrée en local sur le serveur de production.
Faire un backup de la base de donnée locale avec la commande (à lancer en local).
```bash
sh manual-backup-cyclos.sh
```
Un fichier compressé de backup de la base de donnée a été créé, ce fichier doit être décompressé et le fichier sql être copié dans le répertoire `./restoredb` du serveur de production.
Veillez à ce que ce soit le seul fichier du répertoire. Sinon un message d'erreur vous empêchera de continuer.

Sur le serveur de production dans le dossier de l'application, lancer
```bash
sh restoredb-cyclos.sh database-backup-filename.sql
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