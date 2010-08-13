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

  class Validator
    def initialize(spec, interpolator)
      @spec = spec
      @interpolator = interpolator
    end

    def set_value(layer, name, value, options = {})
      return if options[:ignore_bad_settings]

      @spec[name] or raise "No such setting $#{name}"
      @interpolator.interpolate(value)

      #TODO validate by spec :type
    end
  end

  class WriteHookRunner
    def initialize(spec, interpolator)
      @spec = spec
      @interpolator = interpolator
    end

    def set_value(layer, name, value, options = {})
      return if options[:supress_hooks]

      @spec[name][:hook].call( @interpolator.interpolate(value) ) if @spec[name][:hook]
    end
  end

  class TargetWriter
    def initialize(stores_hash)
      @stores = stores_hash
    end

    def set_value(layer, name, value, options = {})
      @stores[layer].set_value(layer, name, value, options)
    end
  end

  class MultiWriter
    def initialize(stores)
      @stores = stores
    end

    def set_value(layer, name, value, options = {})
      @stores.each{ |store| store.set_value(layer, name, value, options) }
    end
  end

  class LayeredReader
    def initialize(stores)
      @stores = stores
    end

    def [](name)
      @stores.inject(nil){ |acc, store| acc || store[name] }
    end
  end

  class Store
    def initialize
      @storage = {}
    end

    def set_value(layer, name, value, options = {})
      @storage[name] = value
    end

    def [](value)
      @storage[value]
    end
  end

  class Defaults
    def initialize(spec)
      @spec = spec
    end

    def [](name)
      @spec[name][:default]
    end
  end

  class Interpolator
    def initialize(source)
      @source = source
      @interpolating = []
    end

    def interpolate(value)
      value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |match|
        @source[ $2 || $1 ]
      end
    end

    def [](name)
      #FIXME: threadsafety
      raise "Interpolation loop detected in $#{name}" if @interpolating.include? name
      @interpolating.push name
      interpolate( @source[name] )
      ensure
        @interpolating.pop
    end
  end

  class Complainer
    def [](name)
      raise "no such parameter $#{name}"
    end
  end

  class ReadWritePair
    def initialize(reader, writer)
      @reader = reader
      @writer = writer
    end

    def [](name)
      @reader[name]
    end

    def set_value(*args)
      @writer.set_value(*args)
    end
  end

  class ForEnvironment
    def initialize( spec, stores_hash, store_names )
      @spec   = spec
      @stores = stores_hash
      @names  = store_names
    end

    def [](environment)
      stores_list = @names.map{ |name| @stores[ name || environment.to_s ] }

      reader = Interpolator.new(
        LayeredReader.new(
          stores_list + [Defaults.new(@spec), Complainer.new]
        )
      )

      writer = MultiWriter.new([
        Validator.new( @spec, reader ),
        WriteHookRunner.new( @spec, reader ),
        TargetWriter.new( @stores )
      ])

      ReadWritePair.new(reader, writer)
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

  stores_hash = Hash.new{|h,k| h[k] = Store.new}

  settings_for_environment = ForEnvironment.new( spec, stores_hash,  [:layer1, :layer2, nil] )

  production_settings = settings_for_environment["production"]
  devel_settings = settings_for_environment["devel"]
  devel_settings.set_value("devel", "moop", "altered")

  production_settings.set_value(:layer1, "meep", "a $moop what")

  p production_settings["meep"]
  p devel_settings["meep"]

  require 'yaml'
  puts production_settings.to_yaml

end
