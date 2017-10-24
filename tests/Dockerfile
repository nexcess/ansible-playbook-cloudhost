
FROM centos:centos7
RUN yum -y install epel-release ansible git
COPY .. /etc/ansible
COPY ./hosts /etc/ansible/hosts
WORKDIR /etc/ansible
ENV PYTHONUNBUFFERED true
ENV ANSIBLE_FORCE_COLOR true
RUN [ -f ./requirements.yml ] && \
    ansible-galaxy install -r ./requirements.yml
CMD eval ansible-playbook \
    -i ./hosts \
    ./playbooks/setup
