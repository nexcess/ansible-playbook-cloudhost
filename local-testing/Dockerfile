FROM centos:centos7
RUN sed -i -e "s/mirrorlist/#mirrorlist/" \
  -e "s/#baseurl/baseurl/" \
  -e "s/mirror.centos.org\/centos\//mirror.us-midwest-1.nexcess.net\/CentOS\//" \
  /etc/yum.repos.d/CentOS-Base.repo
RUN yum clean all && \
  yum -y install epel-release && \
  yum -y install ansible git openssh-clients
RUN mkdir /root/.ssh && chmod 700 /root/.ssh
ADD ./*.key /root/.ssh/
ADD ./ssh-config /root/.ssh/config
RUN chmod 600 /root/.ssh/*
ADD ./hosts.ini /etc/ansible/hosts
ADD ./deployable-vars.yml /etc/ansible/deployable-vars.yml
ADD ./network.yaml /etc/ansible/network.yaml
ADD ./interworx.yaml /etc/ansible/interworx.yaml
ADD ./apache.yaml /etc/ansible/apache.yaml
WORKDIR /opt/playbook
ENV PYTHONUNBUFFERED true
ENV ANSIBLE_FORCE_COLOR true
CMD [ -f requirements.yml ] && \
  ansible-galaxy install -r requirements.yml && \
  eval "$(ssh-agent)" && \
    ssh-add /root/.ssh/*.key && \
    ANSIBLE_CALLBACK_WHITELIST=profile_tasks,timer \
    ansible-playbook \
    -i /etc/ansible/hosts \
    -e @/etc/ansible/deployable-vars.yml \
    -e @/etc/ansible/network.yaml \
    -e @/etc/ansible/interworx.yaml \
    -e @/etc/ansible/apache.yaml \
    ./playbooks/setup.yml
