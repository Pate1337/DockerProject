#!/bin/bash
#
# This script does the same thing as stage1/execute_stage1.sh, except this script
# creates the containers using docker-compose.yml.

# Ask the amount of http servers
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

# Check if docker compose is installed
if ! docker-compose version > /dev/null 2>&1 ; then
	echo "Downloading and installing docker-compose"
	sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
fi

# Remove existing containers
echo ""
echo "Removing existing containers..."
docker rm --force $(docker ps -a --filter='name=^hs[1-5]$|^lb$|^rs$|^bb$' -q)
echo ""
echo "Removing previous builds"
docker-compose down

# Write the docker-compose.yml file
F=docker-compose.yml
echo "# This file is created in a script" > $F
echo "version: '3.7'" >> $F
echo "services:" >> $F
echo "  rs:" >> $F
echo "    image: 'redis'" >> $F
echo "    volumes:" >> $F
echo "      - /var/cec/redis.rdb:/data/dump.rdb" >> $F
echo "  lb:" >> $F
echo "    build:" >> $F
echo "      context: ../stage1/loadbalancer/" >> $F
echo "      dockerfile: ./Dockerfile" >> $F
echo "    ports:" >> $F
echo "      - '7998:7999'" >> $F
echo "    depends_on:" >> $F
echo "      - rs" >> $F

HOST_PORT=8000
CONTAINER_PORT=8080
SERVER_NO=1
while [ $SERVER_NO -le $INPUT ]
do
	SERVER_NAME="hs${SERVER_NO}"
	echo "  ${SERVER_NAME}:" >> $F
	echo "    build:" >> $F
	echo "      context: ../stage1/httpserver/" >> $F
	echo "      dockerfile: ./Dockerfile" >> $F
	if [ ! $CPU_LIMIT -eq 0 ] ; then
		echo "    deploy:" >> $F
		echo "      resources:" >> $F
		echo "        limits:" >> $F
		echo "          cpus: '0.${CPU_LIMIT}'" >> $F
	fi
	echo "    ports:" >> $F
	echo "      - '${HOST_PORT}:${CONTAINER_PORT}'" >> $F
	echo "    depends_on:" >> $F
	echo "      - rs" >> $F
	echo "      - lb" >> $F
	echo "    environment:" >> $F
	echo "      - PORT=${CONTAINER_PORT}" >> $F
	echo "      - HOST=${SERVER_NAME}" >> $F
	((HOST_PORT=HOST_PORT+1))
	((CONTAINER_PORT=CONTAINER_PORT+1))
	((SERVER_NO=SERVER_NO+1))
done

# Build the images based on the created docker-compose.yml file
echo ""
echo "Building images..."
docker-compose build

# Run the containers
echo ""
echo "Running the containers defined in docker-compose.yml"
# --compatibility flag will make the "deploy" part of docker-compose.yml a non-Swarm equivalent
docker-compose --compatibility up -d

echo ""
echo "APPLICATION RUNNING"
echo ""
echo "You can now send a GET request to load balancer server with"
echo ""
echo "node index.js http://localhost:7998/random"
echo ""
echo "OR straight to one of the http servers with"
echo ""
TEMP=0
while [ $TEMP -lt $INPUT ]
do
	echo "node index.js http://localhost:800${TEMP}/random"
	((TEMP=TEMP+1))
done
echo ""
