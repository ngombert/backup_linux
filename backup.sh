#!/bin/bash
##########
# BACKUP DE SERVEUR LINUX (LAMP)
#
# Fichiers : copie local pendant qque jours + copie distante
# Mysql : copie local pendant qque jours + copie distante
# l'arborescence à destination : .../hostname/date/mysql|fichiers|logs
# exemple : /home/happy-garden/preprod.happy-garden.es/20210412/
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



DATE=$(date +"%Y-%m-%d")
HOUR=$(date +"%H%M")
HOSTNAME=$(hostname)


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

if [[ ! -d $LOCAL_MYSQL_BACKUP_DIR ]]
then
    mkdir -p $LOCAL_MYSQL_BACKUP_DIR
fi

if [[ ! -d $LOCAL_FILE_BACKUP_DIR ]]
then
    mkdir -p $LOCAL_FILE_BACKUP_DIR
fi

if [[ ! -d $LOCAL_LOGS_BACKUP_DIR ]]
then
    mkdir -p $LOCAL_LOGS_BACKUP_DIR
fi

# log automatique vers les fichiers
#exec 3>&1 4>&2
#trap 'exec 2>&4 1>&3' 0 1 2 3
#exec 1>${LOCAL_LOGS_BACKUP_DIR}backup.log 2>${LOCAL_LOGS_BACKUP_DIR}error.log


#####
# FILE BACKUP
#####

function local_file_backup() {
    BACKUP_DIR=$1
    FILE_LIST=$2
    RETENTION=$3

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** backing up files to $BACKUP_DIR ****"

    STATUS=0
    for SOURCE in $(cat $FILE_LIST)
    do
        echo "$(date +"%Y%m%d-%H:%M:%S") - copying : $SOURCE"
        rsync -a $SOURCE $BACKUP_DIR
        STATUS=$?
    done

    if [ $STATUS -eq 0 ]
    then
        echo "$(date +"%Y%m%d-%H:%M:%S") - local file backup succeed, cleaning old backups"
        local_purge_old_backup $BACKUP_DIR $RETENTION
    else
        echo "$(date +"%Y%m%d-%H:%M:%S") - local file backup failed, skipping local file purge"
    fi

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** end of local file backup ****"
}

function remote_file_backup() {
    REMOTE_SRV_USER=$1
    REMOTE_SRV_NAME=$2
    REMOTE_SRV_KEY_FILE=$3
    REMOTE_SRV_DIR=$4
    BACKUP_DIR=$5
    RETENTION=$6

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** Starting remote file backup ****"
    if [ ! -f $REMOTE_SRV_KEY_FILE ]
    then
        >&2 echo "$(date +"%Y%m%d-%H:%M:%S") - ERROR : rsync/ssh key file not found"
        exit 1
    fi

    # Create directories in remote if needed
    if ! ssh -i $REMOTE_SRV_KEY_FILE $REMOTE_SRV_USER@$REMOTE_SRV_NAME "test -d ${REMOTE_SRV_DIR}"; then
        ssh -i $REMOTE_SRV_KEY_FILE $REMOTE_SRV_USER@$REMOTE_SRV_NAME "mkdir -p ${REMOTE_SRV_DIR}"
    fi

    echo "$(date +"%Y%m%d-%H:%M:%S") - rsync start"
    rsync -av -e "ssh -i $REMOTE_SRV_KEY_FILE" $BACKUP_DIR $REMOTE_SRV_USER@$REMOTE_SRV_NAME:$REMOTE_SRV_DIR
    echo "$(date +"%Y%m%d-%H:%M:%S") - rsync end"

    if [ $? -eq 0 ]
    then
        echo "$(date +"%Y%m%d-%H:%M:%S") - remote file backup succeed, cleaning old backups"
        remote_purge_old_backup $REMOTE_SRV_USER $REMOTE_SRV_NAME $REMOTE_SRV_KEY_FILE $REMOTE_SRV_DIR $RETENTION
    else
        echo "$(date +"%Y%m%d-%H:%M:%S") - remote file backup failed, skipping old backup purge"
    fi

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** end of remote file backup ****"
}

#####
# MYSQL BACKUP
#####

function mysql_database_backup() {
    DB_SRV=$1
    DB_USER=$2
    DB_PASSWORD=$3
    BACKUP_FILE=$4
    DB_NAME=$5
    MYSQL_OPTIONS="--dump-date --no-autocommit --single-transaction --hex-blob --triggers -R -E"

    echo "$(date +"%Y%m%d-%H:%M:%S") - backing up database $DB_NAME from host $DB_SRV ..."
    mysqldump -u"$DB_USER" -p"$DB_PASSWORD" $MYSQL_OPTIONS "$DB_NAME" | gzip > $BACKUP_FILE
}

function mysql_backup_all() {
    # liste ttes les bdd sauf preformance_schema
    # lance 1 backup par bdd via mysql_database_backup
    DB_SRV=$1
    DB_USER=$2
    DB_PASSWORD=$3
    BACKUP_DIR=$4
    RETENTION=$5

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** start of database backup. ****"

    DB_LIST=$(mysqlshow | grep -v "+\|performance_schema\|Databases" | cut -d" " -f2)

    STATUS=0
    for DB_NAME in $DB_LIST
    do
        mysql_database_backup $DB_SRV $DB_USER $DB_PASSWORD \
        "${BACKUP_DIR}${DATE}-${HOUR}-${DB_NAME}.sql.gz" \
        $DB_NAME
        STATUS=$?
    done

    # if no error during backup then remove old ones
    if [ $STATUS -eq 0 ]
    then
        echo "$(date +"%Y%m%d-%H:%M:%S") - mysql backup succeed, cleaning old backups"
        local_purge_old_backup $BACKUP_DIR $RETENTION
    else
        echo "$(date +"%Y%m%d-%H:%M:%S") - mysql backup failed, skipping old backup purge"
    fi
    echo "$(date +"%Y%m%d-%H:%M:%S") - **** end of database backup. ****"

}

#####
# COMMUN
#####

function local_purge_old_backup() {
    BACKUP_DIR=$1
    RETENTION=$2

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** cleaning old backup (>$RETENTION days) in $BACKUP_DIR ****"
    if [ -z $BACKUP_DIR ]
    then
        >&2 echo "$(date +"%Y%m%d-%H:%M:%S") - ERROR : $BACKUP_DIR non défini ! on risque de vider le disque !!!"
        exit 1
    else
        find $BACKUP_DIR -mtime +${RETENTION} -exec rm -rf {} \;
    fi
    echo "$(date +"%Y%m%d-%H:%M:%S") - **** end of backup cleaning ****"
}

function remote_purge_old_backup() {
    REMOTE_SRV_USER=$1
    REMOTE_SRV_NAME=$2
    REMOTE_SRV_KEY_FILE=$3
    REMOTE_SRV_DIR=$4
    RETENTION=$5

    echo "$(date +"%Y%m%d-%H:%M:%S") - **** cleaning old backup (>$RETENTION days) in $REMOTE_SRV_DIR on $REMOTE_SRV_NAME ****"
    if [ -z $REMOTE_SRV_DIR ]
    then
        >&2 echo "$(date +"%Y%m%d-%H:%M:%S") - ERROR : $REMOTE_SRV_DIR non défini ! on risque de vider le disque !!!"
        exit 1
    else
        ssh -i $REMOTE_SRV_KEY_FILE $REMOTE_SRV_USER@$REMOTE_SRV_NAME "find $REMOTE_SRV_DIR -mtime +${RETENTION} -exec rm -rf {} \;"
    fi
    echo "$(date +"%Y%m%d-%H:%M:%S") - **** end of backup cleaning ****"
}


#####
# MAIN
#####

echo "========================================================================="
echo "= $(date +"%Y%m%d-%H:%M:%S") - BACKUP START"
echo "========================================================================="

mysql_backup_all $DB_SRV_NAME $DB_USER $DB_PASSWORD $LOCAL_MYSQL_BACKUP_DIR $LOCAL_BACKUP_RETENTION
local_file_backup $LOCAL_FILE_BACKUP_DIR $FILE_LIST $RETENTION
remote_file_backup $REMOTE_SRV_USER $REMOTE_SRV_NAME $REMOTE_SRV_KEY_FILE $REMOTE_SRV_DIR $LOCAL_BACKUP_DIR $REMOTE_SRV_RETENTION

echo "========================================================================="
echo "= $(date +"%Y%m%d-%H:%M:%S") - BACKUP END"
echo "========================================================================="
