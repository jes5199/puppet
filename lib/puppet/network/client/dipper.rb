# The client class for filebuckets.
class Puppet::Network::Client::Dipper #XXX < Puppet::Network::Client
    # This is a transitional implementation that uses REST
    # to access remote filebucket files.

    # XXX @handler = Puppet::Network::Handler.handler(:filebucket)
    # XXX @drivername = :Bucket

    attr_accessor :name

    # Create our bucket client
    def initialize(hash = {})
        # Emulate the XMLRPC client
        server      = hash[:Server]
        port        = hash[:Port] || Puppet[:masterport]
        environment = Puppet[:environment]

        if hash.include?(:Path)
            @local_path = hash[:Path]
        else
            Puppet::Status.indirection.terminus_class = :rest
            @rest_path = "https://#{server}:#{port}/#{environment}/bucket_file/"
        end
    end

    # Back up a file to our bucket
    def backup(file)
        unless FileTest.exists?(file)
            raise(ArgumentError, "File %s does not exist" % file)
        end
        contents = ::File.read(file)
        unless local?
            contents = Base64.encode64(contents)
        end
        begin
            return @driver.addfile(contents,file)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            raise Puppet::Error, "Could not back up %s: %s" % [file, detail]
        end
    end

    # Retrieve a file by sum.
    def getfile(sum)
        if newcontents = @driver.getfile(sum)
            unless local?
                newcontents = Base64.decode64(newcontents)
            end
            return newcontents
        end
        return nil
    end

    # Restore the file
    def restore(file,sum)
        restore = true
        if FileTest.exists?(file)
            cursum = Digest::MD5.hexdigest(::File.read(file))

            # if the checksum has changed...
            # this might be extra effort
            if cursum == sum
                restore = false
            end
        end

        if restore
            if newcontents = getfile(sum)
                tmp = ""
                newsum = Digest::MD5.hexdigest(newcontents)
                changed = nil
                if FileTest.exists?(file) and ! FileTest.writable?(file)
                    changed = ::File.stat(file).mode
                    ::File.chmod(changed | 0200, file)
                end
                ::File.open(file, ::File::WRONLY|::File::TRUNC|::File::CREAT) { |of|
                    of.print(newcontents)
                }
                if changed
                    ::File.chmod(changed, file)
                end
            else
                Puppet.err "Could not find file with checksum %s" % sum
                return nil
            end
            return newsum
        else
            return nil
        end
    end
end

