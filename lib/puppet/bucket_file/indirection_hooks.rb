require 'puppet/bucket_file'

# This module is used to pick the appropriate terminus
# in filebucket indirections.
module Puppet::BucketFile::IndirectionHooks
    def select_terminus(request)
        return :rest if request.protocol == 'https'
        return Puppet::BucketFile.indirection.terminus_class
    end
end
