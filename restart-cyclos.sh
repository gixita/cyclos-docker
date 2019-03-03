#!/bin/bash

if [ -e .env ]; then
    source .env
else 
    echo "Please set up your .env file before starting your environment."
    exit 1
fi
echo "Stopping Cyclos only"
docker-compose -f cyclos.yml down
echo "Starting Cyclos only"
docker-compose -f cyclos.yml up -d
echo "Cyclos will take up to 3 minutes to launch."
exit 0
