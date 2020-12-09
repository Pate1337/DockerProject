#!/bin/bash
#
# This script does the same thing as the script in stage2/docker_compose.sh, except this one 
# does not create a docker-compose.yml file.
#
#    I had to start by adding the user "cecuser" to the docker group:
#	sudo usermod -aG docker cecuser
#    After logging out and back in I was able to use docker.
#

# Ask for the amount of http servers
INPUT=0
while [ $INPUT -eq 0 ]
do
	echo ""
	read -p "How many http servers? (1-5 allowed)" INPUT
	if [[ ! $INPUT =~ [1-5] ]] ; then
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

# Remove the existing containers that have the same names as the ones created in this script
echo ""
echo "Removing existing containers..."
docker rm --force $(docker ps -a --filter='name=^hs[1-5]$|^lb$|^rs$|^bb$|^stage2_hs[1-5]_1$|^stage2_rs_1$|^stage2_lb_1$' -q)

# Check if the node-bulletin-board directory exists. If not, clone it.
if [ ! -d /home/cecuser/Project/stage1/node-bulletin-board ]
then
	echo ""
	echo "Cloning node-bulletin-board"
	git clone https://github.com/dockersamples/node-bulletin-board
fi

# Build an image named bulletinboard:1.0 and run a container named bb
cd node-bulletin-board/bulletin-board-app/
echo ""
echo "Building image bulletinboard:1.0"
docker image build -t bulletinboard:1.0 .
echo ""
echo "Running container bb"
docker container run --publish 7000:7080 --detach --name bb bulletinboard:1.0
cd ../../

# Check if there is an image named redis. If not, pull the image.
if test -z "$(docker images -q redis)"; then
	echo ""
	echo "Pulling redis image"
	docker pull redis
fi

# Create a network named mynetwork, if it does not exist.
NETWORK_NAME=mynetwork
if [ -z $(docker network ls --filter name=^${NETWORK_NAME}$ --format="{{ .Name }}") ] ; then
	echo ""
	echo "Network '${NETWORK_NAME}' does not exist, creating '${NETWORK_NAME}'"
	docker network create ${NETWORK_NAME}
fi

# Run a redis container using mynetwork
# Make it provide the snapshot redis.rdb by making a volume of it and adding it to dump.rdb
echo ""
echo "Running redis container"
docker run --net=${NETWORK_NAME} -d --name rs -v /var/cec/redis.rdb:/data/dump.rdb redis

# Build an image called loadbalancer
cd loadbalancer/
echo ""
echo "Building image loadbalancer"
docker image build -t loadbalancer .

# Run a container named lb using mynetwork
# Run this before http servers, because http servers will register to loadbalancer!
echo ""
echo "Running container lb"
docker run --publish 7998:7999 -d --net=${NETWORK_NAME} --name lb loadbalancer

# Build an image named httpserver
cd ../httpserver/
echo ""
echo "Building image httpserver"
docker image build -t httpserver .

# Run as many httpserver containers as the user wants.
# They all use mynetwork
HOST_PORT=8000
CONTAINER_PORT=8080
SERVER_NO=1
CPUS="0.${CPU_LIMIT}"
if [ $CPU_LIMIT -eq 0 ] ; then
	CPUS="1"
fi
while [ $SERVER_NO -le $INPUT ]
do
	SERVER_NAME="hs${SERVER_NO}"
	echo ""
	echo "Running container ${SERVER_NAME}"
	docker run --publish ${HOST_PORT}:${CONTAINER_PORT} -d --net=${NETWORK_NAME} --cpus=${CPUS} -e "PORT=${CONTAINER_PORT}" -e "HOST=${SERVER_NAME}" --name ${SERVER_NAME} httpserver
	((HOST_PORT=HOST_PORT+1))
	((CONTAINER_PORT=CONTAINER_PORT+1))
	((SERVER_NO=SERVER_NO+1))
done

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
