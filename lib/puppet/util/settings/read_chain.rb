class Puppet::Util::Settings::ReadChain
    def initialize(*parts)
        @parts = parts
    end

    def [](key, value = {})
        @parts.inject(value) do |value, part|
            part[key, value]
        end
    end
end

