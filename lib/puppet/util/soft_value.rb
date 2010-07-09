module Puppet::Util
    class SoftValue
        # SoftValues are set when a resource is added for the first time,
        # but the value is not managed on a resource that already exists.
        
        attr_accessor :value

        def initialize(value)
            @value = value
        end

        def to_s
            value.to_s
        end
    end
end
