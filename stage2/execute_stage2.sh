#!/bin/bash

# This script creates a docker swarm using the app.yaml file to build a swarm stack.

# Run swarm without arguments
# It will use the first IP from "hostname -I" as the MANAGER_IP
echo "Initializing swarm"
docker swarm init

# Build an image of the http server
echo ""
echo "Building image 'hs_paavo'"
IMAGE_NAME=hs_paavo
cd httpserver/
docker image build -t ${IMAGE_NAME} .
cd ..

# Ask the amount of replicas
INPUT=0
while [ $INPUT -eq 0 ]
do
	echo ""
	read -p "How many http servers? (1 - 5 allowed)" INPUT
	if [[ ! $INPUT =~ ^[1-5]$ ]] ; then
		INPUT=0
	fi
done

# Ask for a cpu limitation
CPU_LIMIT=100
while [ $CPU_LIMIT -eq 100 ]
do
	echo ""
	read -p "CPU usage of httpserver containers in percentages (0-99, 0 is no limit)" CPU_LIMIT
	if [[ $CPU_LIMIT =~ ^[0]?$ ]] ; then
		CPU_LIMIT=0
	elif [[ ! $CPU_LIMIT =~ ^[1-9][0-9]?$ ]] ; then
		CPU_LIMIT=100
	fi
done
# Handle single digits (add 0 in front)
if [ ! $CPU_LIMIT -eq 0 ] ; then
	if [ $CPU_LIMIT -lt 10 ] ; then
		CPU_LIMIT="0${CPU_LIMIT}"
	fi
fi

# Create the app.yaml file
F=app.yaml
HTTP_SERVICE=hs
HOST_PORT=8005
echo "# This file is created in a script" > $F
echo "version: '3.7'" >> $F
echo "services:" >> $F
echo "  rs:" >> $F
echo "    image: 'redis'" >> $F
echo "    volumes:" >> $F
echo "      - /var/cec/redis.rdb:/data/dump.rdb" >> $F
echo "  ${HTTP_SERVICE}:" >> $F
echo "    image: '${IMAGE_NAME}'" >> $F
echo "    ports:" >> $F
echo "      - '${HOST_PORT}:8080'" >> $F
if [ ! $CPU_LIMIT -eq 0 ] ; then
	echo "    deploy:" >> $F
	echo "      resources:" >> $F
	echo "        limits:" >> $F
	echo "          cpus: '0.${CPU_LIMIT}'" >> $F
fi
echo "    depends_on:" >> $F
echo "     - rs" >> $F

# Deploy stack to Swarm
STACK_NAME=mystack
echo ""
echo "Deploying stack ${STACK_NAME} to swarm"
docker stack deploy -c app.yaml ${STACK_NAME}

# Create replicas
if [ $INPUT -gt 1 ] ; then
	echo ""
	echo "Creating replicas of the container '${HTTP_SERVICE}'"
	docker service scale ${STACK_NAME}_${HTTP_SERVICE}=${INPUT}
fi

echo ""
echo "APPLICATION RUNNING"
echo ""
echo "You can now send a GET request to"
IP=$(hostname -I | cut -f1 -d' ')
echo "http://${IP}:${HOST_PORT}/random"
echo ""
echo "If this url doesn't work, replace the IP with whatever is your MANAGER_IP"
echo ""
