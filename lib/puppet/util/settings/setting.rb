# The base element type.
class Puppet::Util::Settings::Setting
    attr_accessor :name, :section, :default, :setbycli, :call_on_define
    attr_reader :desc, :short

    def self.classify( options )
        if options[:type]
            {:setting => Setting, :file => FileSetting, :boolean => BooleanSetting}[options[:type]] or 
                raise ArgumentError, "Invalid setting type #{options[:type]}"
        else
            case options[:default]
            when Boolean
                BooleanSetting
            when /^\$\w+\//, /^\//
                FileSetting
            else
                Setting
            end
        end
    end

    def self.objectify( options )
        self.classify(options).new(options)
    end

    def desc=(value)
        @desc = value.gsub(/^\s*/, '')
    end

    # get the arguments in getopt format
    def getopt_args
        if short
            [["--#{name}", "-#{short}", GetoptLong::REQUIRED_ARGUMENT]]
        else
            [["--#{name}", GetoptLong::REQUIRED_ARGUMENT]]
        end
    end

    # get the arguments in OptionParser format
    def optparse_args
        if short
            ["--#{name}", "-#{short}", desc, :REQUIRED]
        else
            ["--#{name}", desc, :REQUIRED]
        end
    end

    def munge(value)
        value # default is pass-through
    end

    def hook(value)
        # default is no-op
    end

    def hook=(block)
        meta_def :hook, &block
    end

    # Create the new element.  Pretty much just sets the name.
    def initialize(args = {})
        args.each do |param, value|
            method = param.to_s + "="
            unless self.respond_to? method
                raise ArgumentError, "%s does not accept %s" % [self.class, param]
            end

            self.send(method, value)
        end

        unless self.desc
            raise ArgumentError, "You must provide a description for the %s config option" % self.name
        end
    end

    def iscreated
        @iscreated = true
    end

    def iscreated?
        if defined? @iscreated
            return @iscreated
        else
            return false
        end
    end

    def set?
        if defined? @value and ! @value.nil?
            return true
        else
            return false
        end
    end

    # short name for the celement
    def short=(value)
        if value.to_s.length != 1
            raise ArgumentError, "Short names can only be one character."
        end
        @short = value.to_s
    end

    # Convert the object to a config statement.
    def to_config(settings)
        str = @desc.gsub(/^/, "# ") + "\n"

        # Add in a statement about the default.
        if defined? @default and @default
            str += "# The default value is '%s'.\n" % @default
        end

        # If the value has not been overridden, then print it out commented
        # and unconverted, so it's clear that that's the default and how it
        # works.
        value = settings.value(self.name)

        if value != @default
            line = "%s = %s" % [@name, value]
        else
            line = "# %s = %s" % [@name, @default]
        end

        str += line + "\n"

        str.gsub(/^/, "    ")
    end

    # Retrieves the value, or if it's not set, retrieves the default.
    def value(settings)
        settings.value(self.name)
    end
end

