#!/bin/bash
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

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
