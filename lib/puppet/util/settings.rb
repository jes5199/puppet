require 'sync'
require 'getoptlong'

# The class for handling configuration files.
class Puppet::Util::Settings
    include Enumerable
    include Puppet::Util::Cacher

    require 'puppet/util/settings/setting'
    require 'puppet/util/settings/file_setting'
    require 'puppet/util/settings/boolean_setting'

    attr_accessor :file
    attr_reader :timer

    def initialize
        # Mutex-like thing to protect values
        @sync = Sync.new

        require 'puppet/util/settings/specifications'
        @specifications = Puppet::Util::Settings::Specifications.new

        require 'puppet/util/settings/interpolator'
        @interpolator = Puppet::Util::Settings::Interpolator.new(self)

        @layers = Hash.new
        @mutable_layer_names = []
        @write_layer_name = :memory
        push_layer(:memory)

        @layers_from_config_file = []

        @active_config_file = nil
        @file_watcher = Hash.new do |hash, filename|
            require 'puppet/util/loadedfile'
            hash[filename] = Puppet::Util::LoadedFile.new(filename)
        end

        @currently_looking_up = []
    end

    def read_chain(*layers)
        require 'lib/puppet/util/settings/read_chain'
        Puppet::Util::Settings::ReadChain.new(*layers)
    end

    # Retrieve a config value
    def [](key)
        if @currently_looking_up.include? key
            return nil
        end
        begin
            @currently_looking_up << key
            self.read_chain(* [@specifications.defaults] + current_layers + [ @interpolator, @specifications.read_hooks ] )[key][:value]
        ensure
            @currently_looking_up.delete key
        end
    end

    def include?(key)
        @specifications.include? key
    end

    # Set a config value.  This doesn't set the defaults, it sets the value in a layer.
    def []=(key, value)
        @specifications.validator[key, write_layer] = value
    end

    def write(key, dest, value)
        dest = @layers[dest] || dest

        @specifications.validator[key, dest] = value
    end

    def permanent_layer_names
        ["main", self[:mode], self[:environment], :cli]
    end

    def current_layer_names
        permanent_layer_names + @mutable_layer_names
    end

    def current_layers
        current_layer_names.map{ |name| @layers[name] }.compact
    end

    def write_layer
        @layers[@write_layer_name]
    end

    def push_layer(name)
        @mutable_layer_names.delete name
        @mutable_layer_names.push name
        @layers[name] = Puppet::Util::Settings::Storage.new
    end

    def pop_layer(name = nil)
        @mutable_layer_names.delete name
        @layers.delete name
    end

    def with_temporary_layer(name = nil)
        name ||= Object.new # guaranteed unique key hack
        yield( push_layer(name) )
    ensure
        pop_layer(name)
    end

    def without_noop
        with_temporary_layer do |layer|
            write(:noop, layer, false) if self.include? :noop
            yield
        end
    end

    # Generate the list of valid arguments, in a format that GetoptLong can
    # understand, and add them to the passed option list.
    def addargs(options)
        # Add all of the config parameters as valid options.
        @specifications.metadata.each { |name, setting|
            setting.getopt_args.each { |args| options << args }
        }

        return options
    end

    # Generate the list of valid arguments, in a format that OptionParser can
    # understand, and add them to the passed option list.
    def optparse_addargs(options)
        # Add all of the config parameters as valid options.
        @specifications.metadata.each { |name, setting|
            options << setting.optparse_args
        }

        return options
    end

    # Handle a command-line argument.
    def handlearg(opt, value = nil)
        @cache.clear
        value = munge_value(value) if value
        str = opt.sub(/^--/,'')

        bool = true
        newstr = str.sub(/^no-/, '')
        if newstr != str
            str = newstr
            bool = false
        end
        str = str.intern

        if @config[str].is_a?(Puppet::Util::Settings::BooleanSetting)
            if value == "" or value.nil?
                value = bool
            end
        end

        set_value(str, value, :cli)
    end

    def load_from_file
        raise "No :config setting defined; cannot load unknown config file" unless self[:config]

        # Create a timer so that this file will get checked automatically
        # and reparsed if necessary.
        set_filetimeout_timer()

        @sync.synchronize do
            unsafe_load_from_file(self[:config])
        end
    end

    #this might not be thread safe
    def unsafe_load_from_file(file)
        return unless FileTest.exist?(file)
        begin
            data = parse_file(file)
        rescue => details
            puts details.backtrace if Puppet[:trace]
            Puppet.err "Could not parse #{file}: #{details}"
            return
        end

        clear_layers_from_config_file

        data.each do |section, values|
            @layers_from_config_file.push section
            values.each do |key,value|
                self.write(key, section, value) if self.include? key
            end
        end
    end

    def clear_layers_from_config_file
        @layers_from_config_file.each do |name|
            @layer[name].clear
        end
        @layers_from_config_file = []
    end

    # Reparse our config file, if necessary.
    def reparse
        if @active_config_file != self[:config] || @file_watcher[@active_config_file].changed?
            @active_config_file = file 
            Puppet.notice "Settings file (#{@active_config_file}) has changed"
            load_from_file
        end
    end

    def service_user_available?
        return @service_user_available if defined?(@service_user_available)

        return @service_user_available = false unless user_name = self[:user]

        user = Puppet::Type.type(:user).new :name => self[:user], :check => :ensure

        return @service_user_available = user.exists?
    end

    def set_value(param, value, section, options = {})
        unless setting = @specifications.exists?(param)
            if options[:ignore_bad_settings]
                return
            else
                raise ArgumentError,
                    "Attempt to assign a value to unknown configuration parameter %s" % param.inspect
            end
        end

        value = setting.munge(value)
        setting.hook(value) unless options[:delay_hooks]

        if ReadOnly.include? param
            raise ArgumentError,
                "You're attempting to set configuration parameter $#{param}, which is read-only."
        end

        require 'puppet/util/command_line'
        command_line = Puppet::Util::CommandLine.new
        legacy_to_mode = Puppet::Util::CommandLine::LegacyName.inject({}) do |hash, pair|
            app, legacy = pair
            command_line.require_application app
            hash[legacy.to_sym] = Puppet::Application.find(app).mode.name
            hash
        end
        if new_type = legacy_to_mode[section]
            Puppet.warning "You have configuration parameter $#{param} specified in [#{section}], which is a deprecated section. I'm assuming you meant [#{new_type}]"
            section = new_type
        end
        @sync.synchronize do # yay, thread-safe
            @values[section][param] = value

            # Clear the list of environments, because they cache, at least, the module path.
            # We *could* preferentially just clear them if the modulepath is changed,
            # but we don't really know if, say, the vardir is changed and the modulepath
            # is defined relative to it. We need the defined? stuff because of loading
            # order issues.
            Puppet::Node::Environment.clear if defined?(Puppet::Node) and defined?(Puppet::Node::Environment)
        end

        return value
    end

    # Set a bunch of defaults in a given section.  The sections are actually pretty
    # pointless, but they help break things up a bit, anyway.
    def setdefaults(section, defs)
        call = []
        defs.each { |name, options|
            if options.is_a? Array
                unless options.length == 2
                    raise ArgumentError, "Defaults specified as an array must contain only the default value and the decription"
                end
                options = {
                    :default => options[0],
                    :desc    => options[1]
                }
            end

            @specifications[name] = options
        }
    end

    # Create a timer to check whether the file should be reparsed.
    def set_filetimeout_timer
        return unless timeout = self[:filetimeout] and timeout = Integer(timeout) and timeout > 0
        require 'puppet/external/event-loop'
        timer = EventLoop::Timer.new(:interval => timeout, :tolerance => 1, :start? => true) { self.reparse() }
    end

    def print_configs?
        # Any of several don't-ack-just-introspect settings
        (!self[:configprint].empty?) || self[:genconfig] || self[:genmanifest]
    end

    # Convert the settings we manage into a catalog full of resources that model those settings.
    def to_catalog(*sections)
        sections = nil if sections.empty?

        catalog = Puppet::Resource::Catalog.new("Settings")

        @config.values.find_all { |value| value.is_a?(FileSetting) }.each do |file|
            next unless (sections.nil? or sections.include?(file.section))
            next unless resource = file.to_resource(self)
            next if catalog.resource(resource.ref)

            catalog.add_resource(resource)
        end

        add_user_resources(catalog, sections)

        catalog
    end

    # Convert our list of config settings into a configuration file.
    def to_config
        str = %{The configuration file for #{Puppet[:name]}.  Note that this file
is likely to have unused configuration parameters in it; any parameter that's
valid anywhere in Puppet can be in any config file, even if it's not used.

Every section can specify three special parameters: owner, group, and mode.
These parameters affect the required permissions of any files specified after
their specification.  Puppet will sometimes use these parameters to check its
own configured state, so they can be used to make Puppet a bit more self-managing.

Generated on #{Time.now}.

}.gsub(/^/, "# ")

        # Add a section heading that matches our name.
        if @config.include?(:mode)
            str += "[%s]\n" % self[:mode]
        end
        eachsection do |section|
            persection(section) do |obj|
                str += obj.to_config(self) + "\n" unless ReadOnly.include? obj.name
            end
        end

        return str
    end

    # Convert to a parseable manifest
    def to_manifest
        catalog = to_catalog
        # The resource list is a list of references, not actual instances.
        catalog.resources.collect do |ref|
            catalog.resource(ref).to_manifest
        end.join("\n\n")
    end

    # Create the necessary objects to use a section.  This is idempotent;
    # you can 'use' a section as many times as you want.
    def use(*sections)
        warn "please don't be a user."
    end

    def valid?(param)
        param = param.to_sym
        @config.has_key?(param)
    end

    def change_environment(new_environment)
        push_layer

    end

    # Look in a different environment for the value.
    def value(key, environment = nil)
        environment ||= self[:environment]

        with_temporary_layer do |layer|
            write(:environment, layer, environment)
            self[key]
        end
    end

    private

    # Create the transportable objects for users and groups.
    def add_user_resources(catalog, sections)
        return unless Puppet.features.root?
        return unless self[:mkusers]

        @config.each do |name, setting|
            next unless setting.respond_to?(:owner)
            next unless sections.nil? or sections.include?(setting.section)

            if user = setting.owner and user != "root" and catalog.resource(:user, user).nil?
                resource = Puppet::Resource.new(:user, user, :parameters => {:ensure => :present})
                if self[:group]
                    resource[:gid] = self[:group]
                end
                catalog.add_resource resource
            end
            if group = setting.group and ! %w{root wheel}.include?(group) and catalog.resource(:group, group).nil?
                catalog.add_resource Puppet::Resource.new(:group, group, :parameters => {:ensure => :present})
            end
        end
    end

    # Extract extra setting information for files.
    def extract_fileinfo(string)
        result = {}
        value = string.sub(/\{\s*([^}]+)\s*\}/) do
            params = $1
            params.split(/\s*,\s*/).each do |str|
                if str =~ /^\s*(\w+)\s*=\s*([\w\d]+)\s*$/
                    param, value = $1.intern, $2
                    result[param] = value
                    unless [:owner, :mode, :group].include?(param)
                        raise ArgumentError, "Invalid file option '%s'" % param
                    end

                    if param == :mode and value !~ /^\d+$/
                        raise ArgumentError, "File modes must be numbers"
                    end
                else
                    raise ArgumentError, "Could not parse '%s'" % string
                end
            end
            ''
        end
        result[:value] = value.sub(/\s*$/, '')
        return result
    end

    # Convert arguments into booleans, integers, or whatever.
    def munge_value(value)
        # Handle different data types correctly
        return case value
            when /^false$/i; false
            when /^true$/i; true
            when /^\d+$/i; Integer(value)
            when true; true
            when false; false
            else
                value.gsub(/^["']|["']$/,'').sub(/\s+$/, '')
        end
    end

    # This method just turns a file in to a hash of hashes.
    def parse_file(file)
        text = read_file(file)

        result = Hash.new { |names, name|
            names[name] = {}
        }

        count = 0

        # Default to 'main' for the section.
        section = :main
        result[section][:_meta] = {}
        text.split(/\n/).each { |line|
            count += 1
            case line
            when /^\s*\[(\w+)\]$/
                section = $1.intern # Section names
                # Add a meta section
                result[section][:_meta] ||= {}
            when /^\s*#/; next # Skip comments
            when /^\s*$/; next # Skip blanks
            when /^\s*(\w+)\s*=\s*(.*)$/ # settings
                var = $1.intern

                # We don't want to munge modes, because they're specified in octal, so we'll
                # just leave them as a String, since Puppet handles that case correctly.
                if var == :mode
                    value = $2
                else
                    value = munge_value($2)
                end

                # Check to see if this is a file argument and it has extra options
                begin
                    if value.is_a?(String) and options = extract_fileinfo(value)
                        value = options[:value]
                        options.delete(:value)
                        result[section][:_meta][var] = options
                    end
                    result[section][var] = value
                rescue Puppet::Error => detail
                    detail.file = file
                    detail.line = line
                    raise
                end
            else
                error = Puppet::Error.new("Could not match line %s" % line)
                error.file = file
                error.line = line
                raise error
            end
        }

        return result
    end

    # Read the file in.
    def read_file(file)
        begin
            return File.read(file)
        rescue Errno::ENOENT
            raise ArgumentError, "No such file %s" % file
        rescue Errno::EACCES
            raise ArgumentError, "Permission denied to file %s" % file
        end
    end

    # Set file metadata.
    def set_metadata(meta)
        meta.each do |var, values|
            values.each do |param, value|
                @config[var].send(param.to_s + "=", value)
            end
        end
    end
end
