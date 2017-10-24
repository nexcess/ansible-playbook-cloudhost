#!/bin/sh -xe

if [ "$1" = "7" ]; then
    docker build -t test:1 ./tests
    docker run -t test:1 --volume=`pwd`:/etc/ansible:ro

    ID=$(docker ps | grep centos | awk '{print $1}')

    docker logs $ID
    docker exec --tty $ID env TERM=xterm ansible --version
fi
