#!/bin/bash
# Exit on any individual command failure.
set -e

red='\033[0;31m'
green='\033[0;32m'
neutral='\033[0m'
timestamp=$(date +%s)
distro=${distro:-"centos7"}
playbook=${playbook:-"test.yml"}
cleanup=${cleanup:-"true"}
container_id=${container_id:-$timestamp}

## Set up vars for Docker setup.
opts="--tmpfs /tmp --tmpfs /run --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro --security-opt seccomp=unconfined"

# Run the container using the supplied OS.
printf ${green}"Starting Docker container: sedunne/docker-$distro-ansible"${neutral}"\n"
docker pull sedunne/docker-$distro-ansible:latest
docker run --detach --volume="$PWD":/etc/ansible:rw --name $container_id $opts sedunne/docker-$distro-ansible:latest

printf "\n"

printf ${green}"Installing dependencies if needed..."${neutral}"\n"
docker exec --tty $container_id env TERM=xterm /bin/bash -c 'if [ -e /etc/ansible/requirements.yml ]; then ansible-galaxy install --force -r /etc/ansible/requirements.yml; fi'

printf "\n"

## Run Ansible Lint
printf ${green}"Linting Ansible role/playbook."${neutral}"\n"
docker exec --tty $container_id env TERM=xterm ansible-lint -v /etc/ansible/

printf "\n"

# Run Ansible playbook.
printf ${green}"Running command: docker exec $container_id env TERM=xterm ansible-playbook /etc/ansible/playbooks/ci_setup.yml"${neutral}
docker exec --tty $container_id env TERM=xterm env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/playbooks/ci_setup.yml

# Install Ruby and Bundler
printf ${green}"Installing Ruby and Bundler."${neutral}
docker exec --tty $container_id env TERM=xterm bash -c 'yum install -y centos-release-scl'
docker exec --tty $container_id env TERM=xterm bash -c 'yum-config-manager --enable rhel-server-rhscl-7-rpms'
docker exec --tty $container_id env TERM=xterm bash -c 'yum install -y rh-ruby22'
docker exec --tty $container_id env TERM=xterm bash -c 'source /opt/rh/rh-ruby22/enable; gem install bundler'

# Install Gems and Run Serverspec
printf ${green}"Installing deps and running tests."${neutral}
docker exec --tty $container_id env TERM=xterm bash -c 'PATH="/opt/rh/rh-ruby22/root/usr/local/bin/:${PATH}"; source /opt/rh/rh-ruby22/enable; cd /etc/ansible/ && bundle install --path vendor/ && bundle exec rake'

# Remove the Docker container (if configured).
if [ "$cleanup" = true ]; then
  printf "Removing Docker container...\n"
  docker rm -f $container_id
fi

