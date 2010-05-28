require 'puppet'
require 'sync'
require 'getoptlong'
require 'puppet/external/event-loop'
require 'puppet/util/cacher'
require 'puppet/util/loadedfile'

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
        @specification = Puppet::Util::Settings::Specifications.new

        require 'puppet/util/settings/interpolator'
        @specification = Puppet::Util::Settings::Interpolator.new

        @layers = Hash.new
        @current_layer_names = []
        @write_layer_name = nil
    end

    # Retrieve a config value
    def [](key)
        @specifications.read_chain(*current_layers, @interpolator)[key]
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

    def current_layers
        @current_layer_names.map{ |name| @layers[name] }
    end

    def write_layer
        @layers[@write_layer_name]
    end

    def push_layer(name)
        @current_layer_names.push name
        @layers[name] = {}
    end

    def pop_layer
        @layers.delete @current_layer_names.pop
    end

    def with_layer(name = nil)
        name ||= Object.new # guaranteed unique key hack
        yield( push_layer(name) )
        pop_layer
    end

    def without_noop
        with_layer do |layer|
            write(:noop, layer, false) if self.include? name
            yield
        end
    end

    # Generate the list of valid arguments, in a format that GetoptLong can
    # understand, and add them to the passed option list.
    def addargs(options)
        # Add all of the config parameters as valid options.
        self.each { |name, setting|
            setting.getopt_args.each { |args| options << args }
        }

        return options
    end

    # Generate the list of valid arguments, in a format that OptionParser can
    # understand, and add them to the passed option list.
    def optparse_addargs(options)
        # Add all of the config parameters as valid options.
        self.each { |name, setting|
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

        data.each do |section, values|
            values.each do |key,value|
                self.write(key, section, value) if self.include? key
            end
        end
    end

    # Cache this in an easily clearable way, since we were
    # having trouble cleaning it up after tests.
    cached_attr(:file) do
        if path = self[:config] and FileTest.exist?(path)
            Puppet::Util::LoadedFile.new(path)
        end
    end

    # Reparse our config file, if necessary.
    def reparse
        if file and file.changed?
            Puppet.notice "Reparsing %s" % file.file
            load_from_file
            reuse()
        end
    end

    def reuse
        return unless defined? @used
        @sync.synchronize do # yay, thread-safe
            new = @used
            @used = []
            self.use(*new)
        end
    end

    # The order in which to search for values.
    def searchpath(environment = nil)
        if environment
            [:cli, :memory, environment, :mode, :main]
        else
            [:cli, :memory, :mode, :main]
        end
    end

    # Get a list of objects per section
    def sectionlist
        sectionlist = []
        self.each { |name, obj|
            section = obj.section || "puppet"
            sections[section] ||= []
            unless sectionlist.include?(section)
                sectionlist << section
            end
            sections[section] << obj
        }

        return sectionlist, sections
    end

    def service_user_available?
        return @service_user_available if defined?(@service_user_available)

        return @service_user_available = false unless user_name = self[:user]

        user = Puppet::Type.type(:user).new :name => self[:user], :check => :ensure

        return @service_user_available = user.exists?
    end

    def set_value(param, value, section, options = {})
        unless setting = @specification.exists? param
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
            @cache.clear

            clearused

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

            if options[:call_on_define]
                @queue_hook[name] = true
            end
        }
    end

    def queue_hook(name)
        @hooks_to_call[name] = true
    end

    # Create a timer to check whether the file should be reparsed.
    def set_filetimeout_timer
        return unless timeout = self[:filetimeout] and timeout = Integer(timeout) and timeout > 0
        timer = EventLoop::Timer.new(:interval => timeout, :tolerance => 1, :start? => true) { self.reparse() }
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
        sections = sections.collect { |s| s.to_sym }
        @sync.synchronize do # yay, thread-safe
            sections = sections.reject { |s| @used.include?(s) }

            return if sections.empty?

            begin
                catalog = to_catalog(*sections).to_ral
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                Puppet.err "Could not create resources for managing Puppet's files and directories in sections %s: %s" % [sections.inspect, detail]

                # We need some way to get rid of any resources created during the catalog creation
                # but not cleaned up.
                return
            end

            without_noop do
                catalog.host_config = false
                catalog.apply do |transaction|
                    if transaction.any_failed?
                        report = transaction.report
                        failures = report.logs.find_all { |log| log.level == :err }
                        raise "Got %s failure(s) while initializing: %s" % [failures.length, failures.collect { |l| l.to_s }.join("; ")]
                    end
                end
            end

            sections.each { |s| @used << s }
            @used.uniq!
        end
    end

    def valid?(param)
        param = param.to_sym
        @config.has_key?(param)
    end

    def uninterpolated_value(param, environment = nil)
        param = param.to_sym
        environment = environment.to_sym if environment

        # See if we can find it within our searchable list of values
        val = catch :foundval do
            each_source(environment) do |source|
                # Look for the value.  We have to test the hash for whether
                # it exists, because the value might be false.
                @sync.synchronize do
                    if @values[source].include?(param)
                        throw :foundval, @values[source][param]
                    end
                end
            end
            throw :foundval, nil
        end
        
        # If we didn't get a value, use the default
        val = @config[param].default if val.nil?

        return val
    end

    # Find the correct value using our search path.  Optionally accept an environment
    # in which to search before the other configuration sections.
    def value(param, environment = nil)
        param = param.to_sym
        environment = environment.to_sym if environment

        # Short circuit to nil for undefined parameters.
        return nil unless @config.include?(param)

        # Yay, recursion.
        #self.reparse() unless [:config, :filetimeout].include?(param)

        # Check the cache first.  It needs to be a per-environment
        # cache so that we don't spread values from one env
        # to another.
        if cached = @cache[environment||"none"][param]
            return cached
        end

        val = uninterpolated_value(param, environment)

        # Convert it if necessary
        val = convert(val, environment)

        # And cache it
        @cache[environment||"none"][param] = val
        return val
    end

    # Open a non-default file under a default dir with the appropriate user,
    # group, and mode
    def writesub(default, file, *args, &bloc)
        obj = get_config_file_default(default)
        chown = nil
        if Puppet.features.root?
            chown = [obj.owner, obj.group]
        else
            chown = [nil, nil]
        end

        Puppet::Util::SUIDManager.asuser(*chown) do
            mode = obj.mode || 0640
            if args.empty?
                args << "w"
            end

            args << mode

            # Update the umask to make non-executable files
            Puppet::Util.withumask(File.umask ^ 0111) do
                File.open(file, *args) do |file|
                    yield file
                end
            end
        end
    end

    def readwritelock(default, *args, &bloc)
        file = value(get_config_file_default(default).name)
        tmpfile = file + ".tmp"
        sync = Sync.new
        unless FileTest.directory?(File.dirname(tmpfile))
            raise Puppet::DevError, "Cannot create %s; directory %s does not exist" %
                [file, File.dirname(file)]
        end

        sync.synchronize(Sync::EX) do
            File.open(file, ::File::CREAT|::File::RDWR, 0600) do |rf|
                rf.lock_exclusive do
                    if File.exist?(tmpfile)
                        raise Puppet::Error, ".tmp file already exists for %s; Aborting locked write. Check the .tmp file and delete if appropriate" %
                            [file]
                    end

                    # If there's a failure, remove our tmpfile
                    begin
                        writesub(default, tmpfile, *args, &bloc)
                    rescue
                        File.unlink(tmpfile) if FileTest.exist?(tmpfile)
                        raise
                    end

                    begin
                        File.rename(tmpfile, file)
                    rescue => detail
                        Puppet.err "Could not rename %s to %s: %s" % [file, tmpfile, detail]
                        File.unlink(tmpfile) if FileTest.exist?(tmpfile)
                    end
                end
            end
        end
    end

    private

    def get_config_file_default(default)
        obj = nil
        unless obj = @config[default]
            raise ArgumentError, "Unknown default %s" % default
        end

        unless obj.is_a? FileSetting
            raise ArgumentError, "Default %s is not a file" % default
        end

        return obj
    end

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

    # Yield each search source in turn.
    def each_source(environment)
        searchpath(environment).each do |source|
            # Modify the source as necessary.
            source = self.mode if source == :mode
            yield source
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
