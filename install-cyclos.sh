#!/bin/bash

#
# This file should be used to prepare and run your WebProxy after set up your .env file
# Source: https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion
#

# 1. Check if .env file exists
if [ -e .env ]; then
    source .env
else 
    echo "Please set up your .env file before starting your environment."
    exit 1
fi

# 2. Create docker network
docker network create $NETWORK $NETWORK_OPTIONS

# 4. Download the latest version of nginx.tmpl
curl https://raw.githubusercontent.com/jwilder/nginx-proxy/master/nginx.tmpl > nginx.tmpl

# Check if user set to use Special Conf Files
if [ ! -z ${USE_NGINX_CONF_FILES+X} ] && [ "$USE_NGINX_CONF_FILES" = true ]; then

    # Create the conf folder if it does not exists
    mkdir -p $NGINX_FILES_PATH/conf.d

    # Copy the special configurations to the nginx conf folder
    cp -R ./conf.d/* $NGINX_FILES_PATH/conf.d

    # Check if there was an error and try with sudo
    if [ $? -ne 0 ]; then
        sudo cp -R ./conf.d/* $NGINX_FILES_PATH/conf.d
    fi

    # If there was any errors inform the user
    if [ $? -ne 0 ]; then
        echo
        echo "#######################################################"
        echo
        echo "There was an error trying to copy the nginx conf files."
        echo "The webproxy will still work, your custom configuration"
        echo "will not be loaded."
        echo 
        echo "#######################################################"
    fi
fi 

# # 7. Start application
# echo "Initialize reverse proxy"
# docker-compose -f proxy.yml up -d
# echo "Initialize cyclos database"
# docker-compose -f cyclos.yml up -d cyclos-db
# echo "Waiting 2 min for db creation."
# sleep 120
# echo "Initialize cyclos application"
# docker-compose -f cyclos.yml up -d cyclos-app
# echo "Waiting 4 min for cyclos db tables creation."
# sleep 240
# echo "Initialize cyclos database automatic updates"
# docker-compose -f cyclos.yml up -d pgbackups
# sleep 10
# echo "Initialize cyclos monitoring"
# docker-compose -f monitoring.yml up -d
# echo "Stopping Cyclos only"
# docker-compose -f cyclos.yml down
# echo "Final Cyclos start only"
# docker-compose -f cyclos.yml up -d
# echo "Cyclos will take up to 3 minutes to launch."

exit 0
