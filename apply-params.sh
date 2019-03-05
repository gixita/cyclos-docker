#!/bin/bash

# copying the configuration files to the correct directories
cp ./params/.env ./
cp ./params/alert.rules ./prometheus/alert.rules
cp ./params/prometheus.yml ./prometheus/prometheus.yml
cp ./params/config.monitoring ./grafana/config.monitoring
cp ./params/config.yml ./alertmanager/config.yml

if [ -e .env ]; then
    source .env
else 
    echo "Something went wrong, maybe there is a problem of file permissions."
    exit 1
fi
echo "Parameters applied"
