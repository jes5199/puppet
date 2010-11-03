require 'puppet/util/docs'
require 'puppet/indirector/envelope'
require 'puppet/indirector/request'
require 'puppet/util/cacher'

# The class that connects functional classes with their different collection
# back-ends.  Each indirection has a set of associated terminus classes,
# each of which is a subclass of Puppet::Indirector::Terminus.
class Puppet::Indirector::Indirection
  include Puppet::Util::Cacher
  include Puppet::Util::Docs

  @@indirections = []

  # Find an indirection by name.  This is provided so that Terminus classes
  # can specifically hook up with the indirections they are associated with.
  def self.instance(name)
    @@indirections.find { |i| i.name == name }
  end

  # Return a list of all known indirections.  Used to generate the
  # reference.
  def self.instances
    @@indirections.collect { |i| i.name }
  end

  # Find an indirected model by name.  This is provided so that Terminus classes
  # can specifically hook up with the indirections they are associated with.
  def self.model(name)
    return nil unless match = @@indirections.find { |i| i.name == name }
    match.model
  end

  attr_accessor :name, :model

  # This is only used for testing.
  def delete
    @@indirections.delete(self) if @@indirections.include?(self)
  end

  # Generate the full doc string.
  def doc
    text = ""

    text += scrub(@doc) + "\n\n" if @doc

    if s = terminus_setting
      text += "* **Terminus Setting**: #{terminus_setting}"
    end

    text
  end

  def initialize(model, name, options = {})
    @model = model
    @name  = name

    @terminus_class = options.delete(:terminus_class)
    @cache_class = options.delete(:cache_class)
    @terminus_setting = options.delete(:terminus_setting)

    raise(ArgumentError, "Indirection #{@name} is already defined") if @@indirections.find { |i| i.name == @name }
    @@indirections << self
  end

  def terminus(terminus_name)
    termini[terminus_name] ||= Puppet::Indirector::Terminus.terminus_class(@name, terminus_name).new
  end

  cached_attr(:termini){ Hash.new }

  def default_route
    self.default_route_cache ||= make_route( @terminus_class || terminus_name_from_setting, @cache_class )
  end
  cached_attr(:default_route_cache){ nil }

  def terminus_name_from_setting
    return nil unless @terminus_setting
    Puppet[ @terminus_setting ].to_sym
  end

  def make_route( terminus_name, cache_name = nil )
    routes[ [terminus_name, cache_name] ] ||= (
      main_route = Puppet::Indirector::Route.new( self, terminus_name )
      if @cache_class
        caching_route = Puppet::Indirector::Route.new( self, cache_name )
        Puppet::Indirector::CachingRoute.new( main_route, caching_route )
      else
        main_route
      end
    )
  end
  cached_attr(:routes, :readonly => true){ Hash.new }

  attr_reader :terminus_class, :cache_class

  def cache_class=(klass)
    self.default_route_cache = nil
    @cache_class = klass
  end

  def terminus_class=(klass)
    self.default_route_cache = nil
    @terminus_class = klass
  end

end
