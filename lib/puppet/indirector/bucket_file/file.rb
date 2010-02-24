require 'puppet/indirector/bucket_file'

class Puppet::Indirector::BucketFile::File < Puppet::Indirector::Code
    desc "Store files in a directory set based on their checksums."

    def initialize
        Puppet.settings.use(:filebucket)
    end

    def find( request )
        checksum, path = request_to_type_checksum_and_path( request )
        return model.find_by_checksum( checksum )
    end

    def save( request )
        checksum, path = request_to_type_checksum_and_path( request )

        instance = request.instance
        instance.checksum = checksum if checksum
        instance.path = path if path

        instance.save_to_disk
        instance.to_s
    end

    private 
    def request_to_type_checksum_and_path( request )
        checksum_type, checksum, path = request.key.split(/[:\/]/, 3)
        return nil if checksum_type.to_s == ""
        return [ checksum_type + ":" + checksum, path ]
    end
end
