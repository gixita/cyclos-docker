#!/bin/bash

echo "You need to check afterwards if the backup file is present in the backups folder."
read -p "Do you agree? (y,n)" -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
echo "Backup of database in progress, it can take some time."
docker exec pgbackups /backup.sh 
echo "Backup finished, please ensure that the file is present in the backup directory."
exit 0