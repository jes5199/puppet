require 'puppet/agent'
require 'puppet/agent/runner'
require 'puppet/indirector/code'

class Puppet::Agent::Runner::Local < Puppet::Indirector::Code
    def save( request )
        request.instance.run
    end
end
