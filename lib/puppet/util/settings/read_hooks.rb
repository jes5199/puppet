class Puppet::Util::Settings::ReadHooks
    def initialize( metadata )
        @metadata = metadata
    end

    def [](key,value={})
        @metadata[key].hook(value)
        value
    end
end
