require 'puppet/indirector/filebucket'
require 'puppet/indirector/rest'

class Puppet::Indirector::Filebucket::Rest < Puppet::Indirector::REST
    desc "This is a REST based mechanism to send/retrieve file to/from the filebucket"
end
