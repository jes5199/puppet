class Puppet::Util::Settings::Specifications
    attr :defaults
    attr :validator
    attr :read_hooks
    attr :metadata

    def initialize
        require 'lib/puppet/util/settings/storage'
        @defaults = Puppet::Util::Settings::Storage.new

        @metadata    = Hash.new
        @short_names = Hash.new

        require 'lib/puppet/util/settings/validator'
        @validator = Puppet::Util::Settings::Validator.new(@metadata) 

        require 'lib/puppet/util/settings/read_hooks'
        @read_hooks = Puppet::Util::Settings::ReadHooks.new(@metadata) 
    end

    def []=( name, options )
        if @metadata[name]
            raise Puppet::DevError, "There's already a setting named #{name.inspect}"
        end

        if options[:short] && @short_names[options[:short]]
            raise Puppet::DevError, "There's already a short name #{options[:short].inspect} for #{@short_names[:short].inspect} instead of #{name.inspect}"
        end

        @short_names[options[:short]] = name

        @metadata[name] = Puppet::Util::Settings::Setting.objectify( options.update(:name => name) )
        @validator[name, @defaults] = options[:default]
    end

    def include?(name)
        @metadata.include? name
    end
end
