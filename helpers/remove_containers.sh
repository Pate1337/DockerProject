#!/bin/bash

# Removes all the containers
docker rm --force $(docker ps -a -q)
