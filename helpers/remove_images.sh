#!/bin/bash

docker rmi --force $(docker images -a -q)
