class Puppet::Util::Settings::Validator
    def initialize( metadata )
        @metadata = metadata
    end

    def []=(*args)
        case args.length
        when 3
            key, dest, value = args
        when 2
            key, value = args
            dest = {}
        else
            raise ArgumentError, "wrong number of arguments"
        end

        dest[key] = @metadata[key].munge(value)
    end
end
