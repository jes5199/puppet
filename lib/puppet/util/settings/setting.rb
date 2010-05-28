# The base element type.
class Puppet::Util::Settings::Setting
    attr_accessor :name, :section, :default, :setbycli, :call_on_define
    attr_accessor :read_only
    attr_reader :desc, :short
    attr_writer :hook, :type

    def self.classify( options )
        require 'puppet/util/settings/boolean_setting'
        require 'puppet/util/settings/file_setting'
        if options[:type]
            {:setting => Puppet::Util::Settings::Setting, :file => Puppet::Util::Settings::FileSetting, :boolean => Puppet::Util::Settings::BooleanSetting}[options[:type]] or 
                raise ArgumentError, "Invalid setting type #{options[:type]}"
        else
            case options[:default]
            when true, false # friggin ruby doesn't have a shared superclass for these
                Puppet::Util::Settings::BooleanSetting
            when /^\$\w+\//, /^\//
                Puppet::Util::Settings::FileSetting
            else
                Puppet::Util::Settings::Setting
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
        @hook.call(value) if @hook
    end

    # Create the new element.  Pretty much just sets the name.
    def initialize(args = {})
        @read_only = false
        @hook      = nil

        p args

        args.each do |param, value|
            method = param.to_s + "="

            self.send(method, value)
        end

        unless self.desc
            raise ArgumentError, "You must provide a description for the %s config option" % self.name
        end
    end

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

        if value[:value] != @default
            line = "%s = %s" % [@name, value[:value]]
        else
            line = "# %s = %s" % [@name, @default]
        end

        str += line + "\n"

        str.gsub(/^/, "    ")
    end
end

