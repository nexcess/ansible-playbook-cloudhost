FROM --platform=linux/amd64 centos:7
ENV ANSIBLE_VERSION="2.9.27"
ENV ANSIBLE_LINT_VERSION="4.2.0"
ENV container=docker
WORKDIR /etc/ansible

# CentOS 7 reached EOL on 2024-06-30 and mirrorlist.centos.org no longer
# resolves. Repoint the base/updates/extras repos at the archive before any
# yum command runs.
RUN sed -i \
        -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#[[:space:]]*baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        -e 's|^baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        /etc/yum.repos.d/CentOS-*.repo

# for details on running systemd in a centos container, see:
#  https://hub.docker.com/_/centos/
RUN yum -y update systemd
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;

## setup dependencies
# openssh-server is needed because it generates /etc/ssh/ssh_host_rsa_key which
# iworx default proftpd config expects to exist and other things probably do too
RUN yum makecache fast \
    && yum -y install deltarpm epel-release initscripts \
    && printf '%s\n' \
        '[epel]' \
        'name=Extra Packages for Enterprise Linux 7 - $basearch (archive)' \
        'baseurl=https://archives.fedoraproject.org/pub/archive/epel/7/$basearch/' \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7' \
        > /etc/yum.repos.d/epel.repo \
    && rm -f /etc/yum.repos.d/epel-testing.repo \
    && yum -y install sudo which git python python-pip openssh-server\
    && yum -y update

## install ansible and ansible-lint
# pathlib is bundled with python 3 so packages no longer depend on it
# so we manually add it
RUN pip install --upgrade --no-deps --force-reinstall pathlib
# upgrade pip
RUN pip install --upgrade "pip < 21.0"
# last version of crytography with python 2 support is 3.3.2
RUN pip install --upgrade --no-deps --force-reinstall cryptography==3.3.2
RUN pip install ansible==${ANSIBLE_VERSION} ansible-lint==${ANSIBLE_LINT_VERSION}

# Disable requiretty, and add local inventory file
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/' /etc/sudoers && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

STOPSIGNAL SIGRTMIN+3
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]
