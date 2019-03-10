#!/bin/bash
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

echo "Stop cyclos - pending"
docker-compose -f monitoring.yml down
docker-compose -f cyclos.yml down
docker-compose -f proxy.yml down
if [ "$1" = "force" ]; then
    docker stop $(docker ps -a -q)
    docker rm $(docker ps -a -q)
    echo "All docker containers removed!"
    exit 1
fi
echo "Cyclos stopped."
echo "To stop all containers, please use $ sh stop-all.sh force"
exit 0
