# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.box_check_update = false
  config.vm.hostname = 'cloudhost-ci-test.nexcess.net'
  #config.vm.network "forwarded_port", guest: 80, host: 8080
  #config.vm.network "forwarded_port", guest: 2443, host: 2443
  config.vm.provider "virtualbox" do |vb|
    vb.name = 'cloudhost-ci-test.nexcess.net'
    vb.memory = "2048"
  end
  config.vm.provision "ansible" do |ansible|
    ansible.galaxy_role_file = 'requirements.yml'
    ansible.galaxy_roles_path = 'roles/'
    ansible.playbook = "playbooks/ci_setup.yml"
  end
end
