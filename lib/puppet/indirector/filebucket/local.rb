require 'puppet/indirector/filebucket'

class Puppet::Indirector::Filebucket::Local < Puppet::Indirector::Code
    def find( request )
        hash_type, hash, path = request.key.split('/', 3)
        return model.find_by_hash( hash_type + ":" + hash )
    end

    def save( request )
        p request
        hash_type, hash, path = request.key.split('/', 3)

        instance = request.instance
        instance.hash = hash_type + ":" + hash
        instance.path = path

        print "the instance is "
        p instance

        instance.save_to_disk
        instance.to_s
    end
end
