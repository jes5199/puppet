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

  class EnvironmentSettings
    def initialize(spec, stores, precedence_list)
      @spec   = spec
      @precedence_list = precedence_list
      @stores = stores
    end

    def interpolate(value)
      value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |match|
        self[ $2 || $1 ]
      end
    end

    def [](key)
      interpolate( lookup( key ) )
    end

    def lookup( key )
      read_from_layers(key) || default_value(key) || complain_about(key)
    end

    def read_from_layers( key )
      @precedence_list.inject(nil){ |acc, layer| acc || @stores[layer][key] }
    end

    def default_value(key)
      @spec[key] && @spec[key][:default]
    end

    def complain_about( key )
      raise "no such parameter $#{key}"
    end

    def set_value(layer, key, value, options = {})
      validate(key, value, options)
      call_write_hook(key, value, options)

      @stores[layer][key] = value
    end

    def validate(key, value, options = {})
      return if options[:ignore_bad_settings]

      @spec[key] or raise "No such setting $#{key}"
      interpolate(value)

      #TODO validate by spec :type
    end

    def call_write_hook(key, value, options)
      @spec[key][:hook].call( interpolate(value) ) if !options[:supress_hooks] && @spec[key][:hook]
    end
  end

  def self.environment_settings_factory( spec, precedence_list )
    stores = Hash.new{|h,k| h[k] = Hash.new}

    lambda do |environment|
      return EnvironmentSettings.new(spec, stores, precedence_list.map{ |name| name || environment.to_s } )
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

  settings_for_environment = environment_settings_factory( spec, [:layer1, :layer2, nil] )

  production_settings = settings_for_environment["production"]
  devel_settings = settings_for_environment["devel"]
  devel_settings.set_value("devel", "moop", "altered")

  production_settings.set_value(:layer1, "meep", "a $moop what")

  p production_settings["meep"]
  p devel_settings["meep"]

  require 'yaml'
  puts production_settings.to_yaml

end
