require 'spec_helper'

describe package('MariaDB-server') do
  it { should be_installed.with_version('10.6') }
end

describe package('MariaDB-client') do
  it { should be_installed }
end

describe package('MariaDB-common') do
  it { should be_installed }
end

describe service('mariadb') do
  it { should be_enabled }
  it { should be_running }
end

describe port(3306) do
  it { should be_listening }
end
