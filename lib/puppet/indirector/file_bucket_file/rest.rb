require 'puppet/indirector/bucket_file'
require 'puppet/indirector/rest'

class Puppet::Indirector::BucketFile::Rest < Puppet::Indirector::REST
    desc "This is a REST based mechanism to send/retrieve file to/from the filebucket"
end
