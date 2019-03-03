#!/bin/bash
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
exit 0
