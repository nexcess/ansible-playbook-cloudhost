
FROM centos:centos7
RUN yum clean all && \
    yum -y install epel-release && \
    yum -y install ansible git
WORKDIR /opt
RUN eval git clone git@github.com:nexcess/puppet-config.git \
    -b production puppet
ADD ./hosts /etc/ansible/hosts
WORKDIR /opt/playbook
ENV PYTHONUNBUFFERED true
ENV ANSIBLE_FORCE_COLOR true
RUN [ -f requirements.yml ] && \
    ansible-galaxy install -r requirements.yml
CMD eval ansible-playbook \
    -i /etc/ansible/hosts \
    -e @/opt/puppet/data/common.d/network.yaml \
    -e @/opt/puppet/data/common.d/interworx.yaml \
    -e @/opt/puppet/data/common.d/apache.yaml \
    ./playbooks/setup
