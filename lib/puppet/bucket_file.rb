require 'puppet/indirector'

class Puppet::BucketFile
    extend Puppet::Indirector
    indirects :bucket_file, :terminus_class => :file

    attr :contents
    attr :path, true
    attr :checksum_type

    def initialize( contents, options = {} )
        raise ArgumentError, 'contents must be a string' unless contents.is_a? String
        @contents      = contents
        @path          = nil
        @checksum_type = options[:checksum_type] || self.class.default_checksum_type
        digest_class( @checksum_type )

        if options[:checksum]
            self.checksum = options[:checksum] 
        end
    end

    def self.default_checksum_type
        :md5
    end

    def checksum
        @checksum || calculate_checksum
    end

    def calculate_checksum
        "#{checksum_type}:" + digest_class(checksum_type).hexdigest(contents)
    end

    def default_checksum_type
        @default_checksum_type || self.class.default_checksum_type
    end

    def checksum_type=( new_checksum_type )
        @checksum = nil
        @checksum_type = checksum_type(new_checksum_type)
    end

    def self.find_by_checksum( checksum )
        bpath, bfile = paths( checksum_data(checksum) )

        if ! ::File.exists? bfile
            return nil
        end

        begin
            contents = ::File.read bfile
        rescue RuntimeError => e
            raise Puppet::Error, "file could not be read: #{e.message}"
        end

        self.new( contents, :checksum => checksum )
    end

    def to_s
        contents
    end

    def self.from_s( contents )
        self.new( contents )
    end

    def name
        @checksum.to_s + "/" + @path.to_s
    end

    def checksum=(checksum)
        validate_checksum(checksum)
        @checksum = checksum
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

    def digest_class(h = nil)
        case checksum_type(h)
        when :md5  : Digest::MD5
        when :sha1 : Digest::SHA1
        else
            raise ArgumentError, "not a known checksum type: #{checksum_type}"
        end
    end

    def validate_checksum(new_checksum)
        unless checksum_data(new_checksum) == digest_class(new_checksum).hexdigest(contents)
            raise "checksum does not match contents"
        end
    end

    def self.paths(digest)
        return [
            self.path_for(digest),
            self.path_for(digest, "contents"),
            self.path_for(digest, "paths"),
        ]
    end
    
    def self.path_for(digest, subfile = nil)
        dir = ::File.join(digest[0..7].split(""))
        basedir = ::File.join(Puppet[:bucketdir], dir, digest)
        return basedir unless subfile
        return ::File.join(basedir, subfile)
    end

    def conflict_check?
        true
    end

    def save_to_disk
        bpath, bfile, pathpath = self.class.paths(checksum_data)

        # If the file already exists, just return the md5 sum.
        if ::File.exists?(bfile)
            # If verification is enabled, then make sure the text matches.
            if conflict_check?
                verify(contents, checksum_data, bfile)
            end
            add_path(path, pathpath)
            return checksum_data
        end

        # Make the directories if necessary.
        unless ::File.directory?(bpath)
            Puppet::Util.withumask(0007) do
                ::FileUtils.mkdir_p(bpath)
            end
        end

        # Write the file to disk.
        Puppet.info "Adding #{path} (#{checksum_data}) from REST"

        # ...then just create the file
        Puppet::Util.withumask(0007) do
            ::File.open(bfile, ::File::WRONLY|::File::CREAT, 0440) { |of|
                of.print contents
            }
        end

        # Write the path to the paths file.
        add_path(path, pathpath)

        return checksum_data
    end

    # If conflict_check is enabled, verify that the passed text is
    # the same as the text in our file.
    def verify(content, md5, bfile)
        curfile = ::File.read(bfile)

        # If the contents don't match, then we've found a conflict.
        # Unlikely, but quite bad.
        if curfile != contents
            raise(BucketError,
                "Got passed new contents for sum %s" % md5, caller)
        else
            msg = "Got duplicate (%s)" % [path, md5]
            Puppet.info msg
        end
    end

    def add_path(*args)
        # TODO
    end
end
