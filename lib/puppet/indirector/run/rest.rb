require 'puppet/agent'
require 'puppet/agent/run'
require 'puppet/indirector/rest'

class Puppet::Agent::Run::Rest < Puppet::Indirector::REST
    desc "Trigger Agent runs via REST."
end
