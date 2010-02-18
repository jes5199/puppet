require 'puppet/indirector'

class Puppet::Filebucket
    extend Puppet::Indirector
    indirects :filebucket, :terminus_class => :file

    attr :contents
    attr :path, true
    attr :hash

    def initialize( contents, options = {} )
        @contents = contents
        @path    = nil

        if options[:hash]
            self.hash = options[:hash] 
        else
            calculate_hash
        end
    end

    def default_hash
        "md5"
    end

    def calculate_hash( hash_type = nil )
        hash_type ||= default_hash
        @hash = hash_type + ":" + digest_class(hash_type).hexdigest(contents)
    end

    def self.find_by_hash( hash )
        bpath, bfile = paths( hash_data(hash) )

        if ! ::File.exist? bfile
            return nil
        end

        begin
            contents = ::File.read bfile
        rescue RuntimeError => e
            raise Puppet::Error, "file could not be read: #{e.message}"
        end

        self.new( contents, :hash => hash )
    end

    def to_s
        #[@contents, @path, @hash].inspect
        @contents
    end

    def self.from_s( contents )
        self.new( contents )
    end

    def name
        @hash.to_s + "/" + @path.to_s
    end

    def hash=(hash)
        validate_hash(hash)
        @hash = hash
    end

    def hash_type(new_hash = nil)
        hash = new_hash || self.hash
        hash.split(':',2)[0]
    end

    def self.hash_data(new_hash = nil)
        hash = new_hash || self.hash
        hash.split(':',2)[1]
    end

    def hash_data(new_hash = nil)
        self.class.hash_data(new_hash)
    end

    def digest_class(h = nil)
        case hash_type(h)
        when "md5"  : Digest::MD5
        when "sha1" : Digest::SHA1
        else
            raise "not a known hash type: #{hash_type}"
        end
    end

    def validate_hash(new_hash)
        unless hash_data(new_hash) == digest_class(new_hash).hexdigest(contents)
            raise "hash does not match contents"
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
        digest = digest_class.hexdigest(contents)

        bpath, bfile, pathpath = self.class.paths(digest)

        # If the file already exists, just return the md5 sum.
        if ::FileTest.exists?(bfile)
            # If verification is enabled, then make sure the text matches.
            if conflict_check?
                verify(contents, digest, bfile)
            end
            add_path(path, pathpath)
            return digest
        end

        # Make the directories if necessary.
        unless ::FileTest.directory?(bpath)
            Puppet::Util.withumask(0007) do
                ::FileUtils.mkdir_p(bpath)
            end
        end

        # Write the file to disk.
        Puppet.info "Adding #{path} (#{digest}) from REST"

        # ...then just create the file
        Puppet::Util.withumask(0007) do
            ::File.open(bfile, ::File::WRONLY|::File::CREAT, 0440) { |of|
                of.print contents
            }
        end

        # Write the path to the paths file.
        add_path(path, pathpath)

        return digest
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
