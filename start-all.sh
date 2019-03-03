#!/bin/bash

if [ -e .env ]; then
    source .env
else 
    echo "Please set up your .env file before starting your environment."
    exit 1
fi

docker-compose -f proxy.yml up -d
docker-compose -f cyclos.yml up -d
docker-compose -f monitoring.yml up -d

echo "You can check is Cyclos is launched with"
echo "$ docker logs cyclos-app"
exit 0
