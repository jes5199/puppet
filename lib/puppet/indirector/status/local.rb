require 'puppet/indirector/status'

class Puppet::Indirector::Status::Local < Puppet::Indirector::Code
    def find( hash )
        return model.new( hash )
    end

    def save( options )
        content = options[:content]
        path    = options[:path]
    end
end
