require 'puppet/file_bucket'
require 'puppet/indirector'

class Puppet::FileBucket::File
    # This class handles the abstract notion of a file in a filebucket,
    # and it currently also has the logic for loading and saving disk files
    # on the server-side.
    # The client-side equivalent to that is in Puppet::Network::Client::Dipper
    extend Puppet::Indirector
    require 'puppet/file_bucket/file/indirection_hooks'
    indirects :file_bucket_file, :terminus_class => :file, :extend => Puppet::FileBucket::File::IndirectionHooks

    attr :path, true
    attr :paths, true
    attr :checksum_type
    attr :bucket_path

    def self.default_checksum_type
        :md5
    end

    def initialize( contents, options = {} )
        self.contents= contents
        @bucket_path = options[:bucket_path]
        @path        = options[:path]
        @paths       = options[:paths] || []

        @checksum_type = options[:checksum_type] || self.class.default_checksum_type
        digest_class( @checksum_type ) # raises error on bad types

        @checksum = nil # lazily calculated
        if options[:checksum]
            self.checksum = options[:checksum]
        end
    end

    def checksum=(checksum)
        validate_checksum(checksum)
        self.checksum_type = checksum # this grabs the prefix only
        @checksum = checksum
    end

    def validate_checksum(new_checksum, contents = @contents)
        return unless contents
        unless checksum_data(new_checksum) == digest_class(new_checksum).hexdigest(contents)
            raise Puppet::Error, "checksum does not match contents"
        end
    end

    def contents
        @contents or raise "#{self.inspect} has no contents"
    end

    def contents=(contents)
        raise "can't alter contents of #{self.inspect}" if @contents
        raise ArgumentError, 'contents must be a string or nil' unless contents.nil? || contents.is_a?(String)

        validate_checksum(@checksum, contents) if @checksum
        @contents = contents
    end

    def checksum
        @checksum ||= "#{checksum_type}:" + digest_class(checksum_type).hexdigest(contents)
    end

    def checksum_type=( new_checksum_type )
        @checksum = nil
        @checksum_type = checksum_type(new_checksum_type)
    end

    def checksum_type(checksum = @checksum_type)
        checksum.to_s.split(':',2)[0].to_sym
    end

    def checksum_data(new_checksum = self.checksum)
        checksum.split(':',2)[1]
    end

    def digest_class(type = nil)
        case checksum_type(type)
        when :md5  : require 'digest/md5'  ; Digest::MD5
        when :sha1 : require 'digest/sha1' ; Digest::SHA1
        else
            raise ArgumentError, "not a known checksum type: #{checksum_type(type)}"
        end
    end

    def to_s
        contents
    end

    def name
        [checksum_type, checksum_data, path].compact.join('/')
    end

    def conflict_check?
        true
    end

    def self.from_s( contents )
        self.new( contents )
    end

end
