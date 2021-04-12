#!/bin/bash
##########
# BACKUP DE SERVEUR LINUX (LAMP)
#
# Fichiers : directement en remote vers le serveur
# Mysql : copie local pendant qque jours + copie distante
# l'arborescence à destination : /home/user/hostname/date-heure/mysql|fichiers|logs
# exemple : /home/happy-garden/preprod.happy-garden.es/20210412-1634/
#
# TODO côté serveur de backup : création d'un user par client + ajout de la clé ssh.
#
# IDEE : faire un script de déploiement sur servuer de backup
# add_backup.sh serveur user_dst password_dst user_local
# le script se déploie sur le serveur distant récupère la cle ssh et l'ajoute à l'utilisateur local 
# il crée l'utilisateur local au besoin
#
# IDEE2 : faire script sur le serveur de backup qui génère une page html de statut des backups
# liste les users, vérifie les rep de backup, remonte la date du dernier backup et affiche les logs
# un peu de mise en page toussa/toussa
# avec un htaccess on pourrait facilement avoir un dashboard présentable au client même
# attention filtrage par user dans ce cas.



DATE = $(date +"%Y%m%d")
HOUR = $(date +"%H%M")


if [[ -f backup.conf ]]
then
    . backup.conf
else
    echo "Le fichier de configuration est manquant..."
    exit 1
fi

LOCAL_MYSQL_BACKUP_DIR="${LOCAL_BACKUP_DIR}${DATE}/mysql/"
LOCAL_FILE_BACKUP_DIR="${LOCAL_BACKUP_DIR}${DATE}/files/"
LOCAL_LOGS_BACKUP_DIR="${LOCAL_BACKUP_DIR}${DATE}/logs/"

#####
# FILE BACKUP
#####

function file_backup() {
    ARCHIVE_DIRECTORY="$1/$NOW"
    FILE_LIST="$2"

    if [[ ! -d $ARCHIVE_DIRECTORY ]]
    then
        echo "Création du répertoire de sauvegarde : $ARCHIVE_DIRECTORY"
        mkdir -p $ARCHIVE_DIRECTORY
    fi

    echo "backing up files to $ARCHIVE_FILENAME ..."
    # TODO : install et test rdiff-backup
    rdiff-backup --include-globbing-filelist "$FILE_LIST" --exclude '**' / "$ARCHIVE_DIRECTORY"

    echo "end of file backup."
}


#####
# MYSQL BACKUP
#####

function mysql_database_backup() {
    DB_SRV=$1
    DB_USER=$2
    DB_PASSWORD=$3
    BACKUP_FILE=$4
    LOG_FILE=$5
    DB_NAME=$6
    MYSQL_OPTIONS="--dump-date --no-autocommit --single-transaction --hex-blob --triggers -R -E"

    echo "backing up database $DB_NAME from host $DB_SRV ..."
    mysqldump -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" $MYSQL_OPTIONS | gzip > $BACKUP_FILE 2> $LOG_FILE

    echo "end of database backup."
}

function mysql_backup_all() {
    # liste ttes les bdd sauf preformance_schema
    # lance 1 backup par bdd via mysql_database_backup
    DB_SRV=$1
    DB_USER=$2
    DB_PASSWORD=$3
    BACKUP_DIR=$4
    LOG_DIR=$5

    DB_LIST=$(mysqlshow | grep -v "+\|performance_schema\|Databases" | cut -d" " -f2)

    for DB_NAME in $DB_LIST
    do
        mysql_database_backup $DB_SRV $DB_USER $DB_PASSWORD \
        "${BACKUP_DIR}${DATE}-${HOUR}-${DB_NAME}.sql.gz" \
        "${LOG_DIR}${DATE}-${HOUR}-mysql-${DB_NAME}-error.log" \
        $DB_NAME
    done
}

#####
# COMMUN
#####

function purge_local_old_backup() {
    ARCHIVE_DIRECTORY = $1
    RETENTION_DAYS = $2

    # TODO : 
    rdiff-backup --remove-older-than "$RETENTION_DAYS"D --force "$ARCHIVE_DIRECTORY"
}

function purge_remote_old_backup() {
    # rdiff en remote

    # TODO : 
}

#####
# Main
#####

mysql_backup_all $DB_SRV_NAME $DB_USER $DB_PASSWORD $LOCAL_MYSQL_BACKUP_DIR $LOCAL_LOGS_BACKUP_DIR
#file_backup
#purge_local_old_backup
#purge_remote_old_backup