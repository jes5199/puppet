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

    attr :contents
    attr :path, true
    attr :checksum_type

    def self.default_checksum_type
        :md5
    end

    def initialize( contents, options = {} )
        raise ArgumentError, 'contents must be a string' unless contents.is_a? String

        @contents    = contents
        @path        = options[:path]
        @bucket_path = options[:bucket_path]

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

    def validate_checksum(new_checksum)
        unless checksum_data(new_checksum) == digest_class(new_checksum).hexdigest(contents)
            raise Puppet::Error, "checksum does not match contents"
        end
    end

    def checksum
        @checksum ||= "#{checksum_type}:" + digest_class(checksum_type).hexdigest(contents)
    end

    def checksum_type=( new_checksum_type )
        @checksum = nil
        @checksum_type = checksum_type(new_checksum_type)
    end

    def checksum_type(new_checksum = nil)
        checksum = new_checksum || @checksum_type
        checksum.to_s.split(':',2)[0].to_sym
    end

    def self.checksum_data(new_checksum = nil)
        checksum = new_checksum
        checksum.split(':',2)[1]
    end

    def checksum_data(new_checksum = nil)
        self.class.checksum_data(new_checksum || self.checksum)
    end

    def digest_class(type = nil)
        case checksum_type(type)
        when :md5  : require 'digest/md5'  ; Digest::MD5
        when :sha1 : require 'digest/sha1' ; Digest::SHA1
        else
            raise ArgumentError, "not a known checksum type: #{checksum_type(type)}"
        end
    end

    def self.path_for(bucket_path, digest, subfile = nil)
        bucket_path ||= Puppet[:bucketdir]

        dir     = ::File.join(digest[0..7].split(""))
        basedir = ::File.join(bucket_path, dir, digest)

        return basedir unless subfile
        return ::File.join(basedir, subfile)
    end

    def self.contents_save_path( bucket_path, checksum )
        self.path_for( bucket_path, checksum_data( checksum ), "contents")
    end

    def save_path(subfile = nil)
        self.class.path_for(@bucket_path, checksum_data, subfile)
    end

    def contents_save_path
        save_path("contents")
    end

    def paths_save_path
        save_path("paths")
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

    def save_to_disk
        # If the file already exists, just return the md5 sum.
        if ::File.exists?(contents_save_path)
            verify!
        else
            # Make the directories if necessary.
            unless ::File.directory?(save_path)
                Puppet::Util.withumask(0007) do
                    ::FileUtils.mkdir_p(save_path)
                end
            end

            Puppet.info "FileBucket::File adding #{path} (#{checksum_data})"

            # Write the file to disk.
            Puppet::Util.withumask(0007) do
                ::File.open(contents_save_path, ::File::WRONLY|::File::CREAT, 0440) do |of|
                    of.print contents
                end
            end
        end

        save_path_to_paths_file!
        return checksum_data
    end

    def content_check?
        true
    end

    # If conflict_check is enabled, verify that the passed text is
    # the same as the text in our file.
    def verify!
        return unless content_check?
        disk_contents = ::File.read(contents_save_path)

        # If the contents don't match, then we've found a conflict.
        # Unlikely, but quite bad.
        if disk_contents != contents
            raise BucketError, "Got passed new contents for sum #{checksum}", caller
        else
            Puppet.info "FileBucket::File got a duplicate file #{path} (#{checksum})"
        end
    end

    def save_path_to_paths_file!
        return unless path

        # check for dupes
        if ::File.exists?(paths_save_path)
            ::File.open(paths_save_path) do |f|
                return if f.readlines.collect { |l| l.chomp }.include?(path)
            end
        end

        # if it's a new file, or if our path isn't in the file yet, add it
        File.open(paths_save_path, ::File::WRONLY|::File::CREAT|::File::APPEND) do |of|
            of.puts path
        end
    end

    def paths
        return @paths if @paths

        if ::File.exists?(paths_save_path)
            ::File.open(paths_save_path) do |f|
                @paths = f.readlines.map { |l| l.chomp }
            end
        else
            @paths = []
        end

        return @paths
    end

    def self.find_by_checksum( checksum, bucket_path = nil )
        load_from_file = self.contents_save_path( bucket_path, checksum )

        if ! ::File.exists? load_from_file
            return nil
        end

        begin
            contents = ::File.read load_from_file
        rescue RuntimeError => e
            raise Puppet::Error, "file could not be read: #{e.message}"
        end

        self.new( contents, :checksum => checksum )
    end

    def self.from_s( contents )
        self.new( contents )
    end

end
