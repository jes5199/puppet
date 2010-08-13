module Puppet ; end
module Puppet::Util ; end
module Puppet::Util::Settings
  class Specification
    def initialize
      @specs = {}
    end

    def define(section, definitions)
      definitions.each do |name, options|
        if options.is_a? Array
          options = {:default => options[0], :desc => options[1]}
        end

        @specs[name] = options
      end
    end

    def [](name)
      @specs[name]
    end

  end

  def validator(spec, interpolate_value)
    lambda do |layer, name, value, options|
      return if options[:ignore_bad_settings]

      spec[name] or raise "No such setting $#{name}"
      interpolate_value[value]

      #TODO validate by spec :type
    end
  end

  def write_hook_runner(spec, interpolate_value)
    lambda do |layer, name, value, options|
      return if options[:supress_hooks]

      spec[name][:hook].call( interpolate_value(value) ) if spec[name][:hook]
    end
  end

  def target_writer(stores_hash)
    lambda do |layer, name, value, options|
      stores_hash[layer][name] = value
    end
  end

  def multiwriter(stores)
    lambda { |layer, name, value, options|
      stores.each{|store| store[layer, name, value, options] }
    }
  end

  def layered_reader(stores)
    lambda do |name|
      stores.inject(nil){ |acc, store| acc || store[name] }
    end
  end

  def defaults(spec)
    lambda do |name|
      spec[name][:default]
    end
  end

  def interpolator(source)
    lookup_and_interp = nil # for the closure

    interp = lambda do |value|
      value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |match|
        lookup_and_interp[ $2 || $1 ]
      end
    end

    lookup_and_interp = lambda do |key|
      interp[ source[key] ]
    end

    return [interp, lookup_and_interp]
  end

  def complainer
    lambda do |name|
      raise "no such parameter $#{name}"
    end
  end

  class ForEnvironment
    def initialize( spec, store_names )
      @stores = Hash.new{|h,k| h[k] = Hash.new}

      @spec   = spec
      @stores = stores_hash
      @names  = store_names
    end

    def [](environment)
      stores_list = @names.map{ |name| @stores[ name || environment.to_s ] }

      interpolate_only, reader = interpolator(
        layered_reader(
          stores_list + [defaults(@spec), complainer]
        )
      )

      writer = multiwriter([ 
        validator( @spec, interpolate_only ),
        write_hook_runner( @spec, interpolate_only ),
        target_writer( @stores )
      ])

      return [reader, writer]
    end
  end

  spec = Specification.new
  spec.define(:section,
    "moop" => ['default', 'desc'],
    "meep" => {
      :default => 'meeper',
      :desc    => 'meeper',
      :hook    => lambda {|value|
        puts "I'm storing #{value.inspect}"
      }
    }
  )

  settings_for_environment = ForEnvironment.new( spec, [:layer1, :layer2, nil] )

  production_settings = settings_for_environment["production"]
  devel_settings = settings_for_environment["devel"]
  devel_settings.set_value("devel", "moop", "altered")

  production_settings.set_value(:layer1, "meep", "a $moop what")

  p production_settings["meep"]
  p devel_settings["meep"]

  require 'yaml'
  puts production_settings.to_yaml

end
