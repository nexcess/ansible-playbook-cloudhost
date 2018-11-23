require 'spec_helper'

describe package('php56') do
  it { should be_installed }
end

describe package('php70') do
  it { should be_installed }
end

describe package('php71') do
  it { should be_installed }
end
