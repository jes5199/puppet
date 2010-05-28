class Puppet::Util::Settings::Interpolator
    def intialize( settings )
        @settings = settings
    end

    def [](key,value = {})
        string = value[:value]
        if string.is_a? String
            value[:value] = string.gsub(/\$(\w+)|\$\{(\w+)\}/) do |variable|
                varname = $2 || $1
                @settings.include?(varname) or
                    raise Puppet::DevError, "Could not find value for #{variable} (used in #{key})"
                @settings[varname][:value]
            end
        end

        value
    end
end
