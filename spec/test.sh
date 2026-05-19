#!/bin/bash
# Exit on any individual command failure.
set -e

# Pretty colors.
red="$(tput setaf 1)"
green="$(tput setaf 2)"
neutral="$(tput sgr0)"


DISTRO=${DISTRO:-"centos7"}
cleanup=${cleanup:-"true"}
container_id=${container_id:-$(date +%s)}
docker_image="nexcess/ansible-playbook-cloudhost:${DISTRO}"
dockerfile="Dockerfile.${DISTRO}"

## Build docker container if it isn't already built (e.g. running locally).
if [[ "$(docker images -q "${docker_image}" 2> /dev/null)" == "" ]]; then
  printf "%s\n" "${green}Building Docker image: ${docker_image}${neutral}"
  docker build -t "${docker_image}" -f "${dockerfile}" .
fi

## Set up vars for Docker setup.
# --cgroupns=host is required for CentOS 7's systemd to boot inside Docker
# 20.10+, which otherwise puts the container in a private cgroup namespace
# that systemd v219 can't navigate (DBus never comes up). The cgroup mount
# also needs to be rw so systemd can create its own slice/scope dirs.
opts=(--privileged --cgroupns=host --tmpfs /tmp --tmpfs /run --tmpfs /run/lock --volume=/sys/fs/cgroup:/sys/fs/cgroup:rw --security-opt seccomp=unconfined)


# Run the container using the supplied OS.
printf "%s\n" "${green}Starting Docker container: ${docker_image}${neutral}"
docker run \
  --detach \
  --volume="$PWD":/etc/ansible:rw \
  --name "$container_id" \
  --hostname "ci-test.nexcess.net" \
  "${opts[@]}" \
  "${docker_image}"

# give systemd time to boot
attempts=0
printf "%s\n" "${green}Checking if systemd has booted...${neutral}"
while ! docker exec "$container_id" systemctl list-units > /dev/null 2>&1; do
  if ((attempts > 11)); then
    printf "%s\n" "${red}Giving up waiting for systemd!${neutral}"
    exit 1
  fi
  printf "%s\n" "${green}Sleeping for 5 seconds...${neutral}"
  sleep 5
  attempts=$((attempts + 1))
done


printf "%s\n" "${green}Installing dependencies if needed...${neutral}"
docker exec --tty "$container_id" env TERM=xterm /bin/bash -c 'if [ -e /etc/ansible/requirements.yml ]; then ansible-galaxy install -r /etc/ansible/requirements.yml; fi'
printf "\n"

# ANSIBLE_INVALID_TASK_ATTRIBUTE_FAILED=false demotes the deprecated `static:`
# attribute used by nexcess.php's include task from a fatal error to a warning
# in ansible-core 2.14+. EL7 ships ansible 2.9 which doesn't know the option;
# the env var is silently ignored there.
ansible_env=(env TERM=xterm ANSIBLE_FORCE_COLOR=1 ANSIBLE_INVALID_TASK_ATTRIBUTE_FAILED=false)

## Run Ansible Lint
printf "%s\n" "${green}Linting Ansible role/playbook.${neutral}"
docker exec --tty "$container_id" "${ansible_env[@]}" ansible-lint -v /etc/ansible/
printf "\n"

# Run Ansible playbook.
printf "%s\n" "${green}Running command: docker exec $container_id ansible-playbook /etc/ansible/playbooks/ci_setup.yml${neutral}"
docker exec --tty "$container_id" "${ansible_env[@]}" ansible-playbook /etc/ansible/playbooks/ci_setup.yml
printf "\n"

# Install Ruby + Bundler. CentOS 7 uses SCL rh-ruby26 (system ruby is 2.0
# which is too old for serverspec). Rocky 9 ships ruby 3.0 in AppStream.
printf "%s\n" "${green}Installing Ruby and Bundler.${neutral}"
case "$DISTRO" in
  centos7)
    docker exec --tty "$container_id" env TERM=xterm bash -c 'yum install -y centos-release-scl'
    # The SCL repos installed above also point at the dead mirrorlist; repoint
    # them at vault.centos.org so rh-ruby26 can resolve.
    docker exec --tty "$container_id" env TERM=xterm bash -c "sed -i \
        -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#[[:space:]]*baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        -e 's|^baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        /etc/yum.repos.d/CentOS-SCLo-*.repo"
    docker exec --tty "$container_id" env TERM=xterm bash -c 'yum-config-manager --enable rhel-server-rhscl-7-rpms'
    docker exec --tty "$container_id" env TERM=xterm bash -c 'yum install -y rh-ruby26'
    docker exec --tty "$container_id" env TERM=xterm bash -c 'source /opt/rh/rh-ruby26/enable; gem install bundler -v "1.17.3"'
    ruby_env='PATH="/opt/rh/rh-ruby26/root/usr/local/bin/:${PATH}"; source /opt/rh/rh-ruby26/enable'
    ;;
  rocky9)
    docker exec --tty "$container_id" env TERM=xterm bash -c 'dnf install -y ruby ruby-devel rubygem-bundler gcc redhat-rpm-config make'
    ruby_env='true'
    ;;
  *)
    printf "%s\n" "${red}Unsupported DISTRO=${DISTRO}${neutral}"
    exit 1
    ;;
esac

# Install Gems and Run Serverspec
printf "%s\n" "${green}Installing deps and running tests.${neutral}"
docker exec --tty "$container_id" env TERM=xterm bash -c "${ruby_env}; cd /etc/ansible/ && bundle install --path vendor/ && bundle exec rake ${DISTRO}"

# Remove the Docker container (if configured).
if [ "$cleanup" = true ]; then
  printf "Removing Docker container...\n"
  docker rm -f "$container_id"
fi
