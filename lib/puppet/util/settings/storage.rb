class Puppet::Util::Settings::Storage
    def initialize
        @storage = Hash.new
    end

    def [](name, value={})
        value.update(@storage[name])
    end

    def []=(name, value_or_options)
        @storage[name] = if value_or_options.is_a? Hash
            value_or_options
        else
            {:value => value_or_options}
        end
    end

    def include?(name)
        @storage.include? name
    end
end

