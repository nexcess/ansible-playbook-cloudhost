require 'spec_helper'

describe package('interworx'), :if => os[:family] == 'redhat' do
  it { should be_installed }
end

describe service('iworx'), :if => os[:family] == 'redhat' do
  it { should be_enabled }
  it { should be_running }
end

describe port(2443) do
  it { should be_listening }
end

describe package('libnss-mysql') do
  it { should be_installed }
end

describe command('/home/interworx/bin/config.pex --global --get --name SITEWORX_SSH_FEATURE') do
  its(:stdout) { should match /on/ }
end

describe command('/bin/nodeworx -unv -c Http -a listPhpInstallMode') do
  its(:stdout) { should match /php-fpm/ }
end

describe command('/bin/nodeworx -unv -c Http -a queryMultiplePhpOptions') do
  its(:stdout) { should match /default_php_version\:\ \/opt\/remi\/php71/ }
end
