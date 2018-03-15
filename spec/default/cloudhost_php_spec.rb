require 'spec_helper'

describe package('php56') do
  it { should be_installed }
end

describe service('php56-php-fpm') do
  it { should be_enabled }
  it { should be_running }
end

describe package('php70') do
  it { should be_installed }
end

describe service('php70-php-fpm') do
  it { should be_enabled }
  it { should be_running }
end

describe package('php71') do
  it { should be_installed }
end

describe service('php71-php-fpm') do
  it { should be_enabled }
  it { should be_running }
end
