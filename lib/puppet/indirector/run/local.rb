require 'puppet/agent'
require 'puppet/agent/run'
require 'puppet/indirector/code'

class Puppet::Agent::Run::Local < Puppet::Indirector::Code
    def save( request )
        request.instance.run
    end
end
