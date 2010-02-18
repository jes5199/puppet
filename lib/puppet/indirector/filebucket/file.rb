require 'puppet/indirector/filebucket'

class Puppet::Indirector::Filebucket::File < Puppet::Indirector::Code
    desc "Store files in a directory set based on their checksums."

    def initialize
        Puppet.settings.use(:filebucket)
    end

    def find( request )
        hash_type, hash, path = request.key.split('/', 3)
        return model.find_by_hash( hash_type + ":" + hash )
    end

    def save( request )
        hash_type, hash, path = request.key.split('/', 3)

        instance = request.instance
        instance.hash = hash_type + ":" + hash
        instance.path = path if path

        instance.save_to_disk
        instance.to_s
    end
end
