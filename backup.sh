#!/bin/bash

NOW=$(date +"%Y%m%d-%H%M%S")
DEST_DIR="./sandbox/dest/"

function file_backup {
    DEST_FILE="${DEST_DIR}${NOW}-${2}"
    echo "backing up files in $1 to $DEST_FILE ..."
    tar -zcf $DEST_FILE $1

    echo "end of file backup."
}

function mysql_backup {
    echo "backing up database $1 from host $2 ..."


    echo "end of database backup."
}


###
# Main
###

file_backup ./sandbox/test_rep test.tar.gz
mysql_backup prestashop localhost
mysql_backup prestashop_dev localhost