#!/bin/bash
# Exit on any individual command failure.
set -e

# Pretty colors.
red="$(tput setaf 1)"
green="$(tput setaf 2)"
neutral="$(tput sgr0)"


playbook=${playbook:-"test.yml"}
distro=${distro:-"centos7"}
cleanup=${cleanup:-"true"}
container_id=${container_id:-$(date +%s)}
docker_image='nexcess/ansible-playbook-cloudhost'

## Build docker container
if [[ "$(docker images -q "${docker_image}:latest" 2> /dev/null)" == "" ]]; then
  printf "%s\n" "${green}Building Docker image: ${docker_image}${neutral}"
  docker build -t "nexcess/ansible-role-interworx:latest" - < Dockerfile
fi

## Set up vars for Docker setup.
opts=(--privileged --tmpfs /tmp --tmpfs /run --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro --security-opt seccomp=unconfined)


# Run the container using the supplied OS.
printf "%s\n" "${green}Starting Docker container: ${docker_image}${neutral}"
docker run --detach --volume="$PWD":/etc/ansible:rw --name "$container_id" "${opts[@]}" "${docker_image}:latest"

# give systemd time to boot
attempts=0
printf "%s\n" "${green}Checking if systemd has booted...${neutral}"
while ! docker exec "$container_id" systemctl list-units > /dev/null 2>&1; do
  if ((attempts > 5)); then
    printf "%s\n" "${red}Giving up waiting for systemd! Output below:${neutral}"
    docker exec "$container_id" systemctl list-units
    printf "\n"
    break
  fi
  printf "%s\n" "${green}Sleeping for 5 seconds...${neutral}"
  sleep 5
  attempts=$((attempts + 1))
done


printf "%s\n" "${green}Installing dependencies if needed...${neutral}"
docker exec --tty "$container_id" env TERM=xterm /bin/bash -c 'if [ -e /etc/ansible/requirements.yml ]; then ansible-galaxy install -r /etc/ansible/requirements.yml; fi'
printf "\n"

## Run Ansible Lint
printf "%s\n" "${green}Linting Ansible role/playbook.${neutral}"
docker exec --tty "$container_id" env TERM=xterm ansible-lint -v /etc/ansible/
printf "\n"

# Run Ansible playbook.
printf "%s\n" "${green}Running command: docker exec $container_id env TERM=xterm ansible-playbook /etc/ansible/playbooks/ci_setup.yml${neutral}"
docker exec --tty "$container_id" env TERM=xterm env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/playbooks/ci_setup.yml
printf "\n"

# Install Ruby and Bundler
printf "%s\n" "${green}Installing Ruby and Bundler.${neutral}"
docker exec --tty "$container_id" env TERM=xterm bash -c 'yum install -y centos-release-scl'
docker exec --tty "$container_id" env TERM=xterm bash -c 'yum-config-manager --enable rhel-server-rhscl-7-rpms'
docker exec --tty "$container_id" env TERM=xterm bash -c 'yum install -y rh-ruby26'
docker exec --tty "$container_id" env TERM=xterm bash -c 'source /opt/rh/rh-ruby26/enable; gem install bundler -v "1.17.3"'

# Install Gems and Run Serverspec
printf "%s\n" "${green}Installing deps and running tests.${neutral}"
docker exec --tty "$container_id" env TERM=xterm bash -c 'PATH="/opt/rh/rh-ruby26/root/usr/local/bin/:${PATH}"; source /opt/rh/rh-ruby26/enable; cd /etc/ansible/ && bundle install --path vendor/ && bundle exec rake'

# Remove the Docker container (if configured).
if [ "$cleanup" = true ]; then
  printf "Removing Docker container...\n"
  docker rm -f "$container_id"
fi
