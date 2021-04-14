# BACKUP LINUX
## Sauvegarde de fichier et de base de données en local et distant

Ce script sauvegarde un ou plusieurs répertoires ainsi que toutes les base de données d'un serveur mysql.

## Features

- Sauvegarde de fichiers
- Sauvegarde de base de données
- Copie de la sauvegarde local vers un serveur distant via rsync/ssh
- Gestion de la durée de rétention (locale et distante)
- log des actions

## Prérequis

- rsync
- mysqldump
- mysqlshow


## Installation

Il suffit de décompresser l'archive dans un répertoire.
Le script peut être lancé à la main ou placé dans une tache cron

Par exemple :
```sh
cd /opt
tar -zxvf /chemin/de/larchive/backup_lamp.tar.gz
cd Backup_linux
chmod +x backup.sh
```
## Configuration du script 

La configuration du script se fait dans le fichier backup.conf
Les variables suivantes doivent être définies :

| Variable | Fonction |
| ------ | ------ |
| FILE_LIST | Fichier contenant la liste des fichiers/répertoires à sauvegarder |
| LOCAL_BACKUP_DIR | Répertoire de destination pour la sauvegarde locale |
| LOCAL_BACKUP_RETENTION | Nombre de jours de rétention en local |
| REMOTE_SRV_NAME | IP/DNS du serveur de backup distant |
| REMOTE_SRV_USER | Utilisateur sur le serveur distant |
| REMOTE_SRV_DIR | Répertoire de destination pour la sauvegarde distante |
| REMOTE_SRV_RETENTION | Nombre de jours de rétention à distance |
| REMOTE_SRV_KEY_FILE | Clef privée pour l'authentification ssh |
| DB_SRV_NAME | IP/DNS du serveur de base de donnée |
| DB_USER | Utilisateur BDD |
| DB_PASSWORD | Mot de passe BDD |

## Configuration du serveur distant

TODO
