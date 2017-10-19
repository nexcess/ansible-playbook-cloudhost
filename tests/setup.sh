#!/bin/sh -xe

if [ "$1" = "7" ]; then
    docker run --detach --privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro geerlingguy/docker-centos7-ansible:latest /usr/lib/systemd/systemd --volume=`pwd`:/etc/ansible:ro

    ID=$(docker ps | grep centos | awk '{print $1}')

    docker logs $ID
    docker exec --tty $ID env TERM=xterm ansible --version
    docker exec --tty $ID env TERM=xterm playbook setup
fi
