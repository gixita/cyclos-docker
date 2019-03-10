#!/bin/bash
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

# copying the configuration files to the correct directories
cp ./params/.env ./
cp ./params/alert.rules ./prometheus/alert.rules
cp ./params/prometheus.yml ./prometheus/prometheus.yml
cp ./params/config.monitoring ./grafana/config.monitoring
cp ./params/config.yml ./alertmanager/config.yml

if [ -e .env ]; then
    echo "${GREEN}The environnement variables files are copied.${NC}"
else 
    echo "Something went wrong, maybe there is a problem of file permissions."
    exit 1
fi
source .env
echo "Parameters applied ${GREEN}done${NC}"
