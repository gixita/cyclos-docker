#!/bin/bash

echo "############################"
echo "#       ATTENTION          #"
echo "############################"
echo ""
echo "This procedure is irreversible."
echo "You should have done a manual backup before continue."
echo ""
read -p "Did you create a manual backup and want to proceed to a database replacement ? (y,n)" -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cancel procedure..."
    sleep 1
    echo "Procedure cancelled"
    exit 1
fi

if [ -e .env ]; then
    source .env
else 
    echo "ERROR : Please set up your .env file before starting your environment."
    echo "Procedure cancelled"
    exit 1
fi

if [ $(find ./restoredb -type f -name "*.sql*" | wc -l) -ne 1 ]; then
    echo "ERROR : You can only have one sql file in the restoredb directory"
    echo "Procedure cancelled"
    exit 1
fi
if [ $(find ./restoredb -type f -name "$1" | wc -l) -ne 1 ]; then
    echo "ERROR : There is no file $1 in the directory restoredb"
    exit 1
fi

echo "Starting replacement procedure"

echo ""
echo "Stopping all application containers"
docker-compose -f monitoring.yml down
docker-compose -f cyclos.yml down
docker-compose -f proxy.yml down

echo "Delete old database"
rm -rf ./db-data/*
echo "Start Cyclos Database container"

docker run -d \
    --name=cyclos-restore-db \
    --hostname=cyclos-db \
    -v $(pwd)/db-data:/var/lib/postgresql/data \
    -v $(pwd)/restoredb:/restoredb \
    -e POSTGRES_DB=${CYCLOS_DB_NAME} \
    -e POSTGRES_USER=${CYCLOS_DB_USER} \
    -e POSTGRES_PASSWORD=${CYCLOS_DB_PASSWORD} \
    cyclos/db
echo "Wait 1 minute, Cyclos database is starting"
sleep 60
echo "Start modifying initialized database"
docker exec -it cyclos-restore-db psql -U ${CYCLOS_DB_USER} -d ${CYCLOS_DB_NAME} -f /restoredb/$1

docker stop cyclos-restore-db
docker rm cyclos-restore-db

echo "Database replaced. To start Cyclos run "
echo "$ sh start-all.sh"


exit 0