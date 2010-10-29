# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection is configured via the
# +indirects+ method, which will be called by the class extending itself
# with this module.
module Puppet::Indirector
  # LAK:FIXME We need to figure out how to handle documentation for the
  # different indirection types.

  require 'puppet/indirector/indirection'
  require 'puppet/indirector/terminus'
  require 'puppet/indirector/envelope'
  require 'puppet/indirector/route'
  require 'puppet/indirector/caching_route'
  require 'puppet/network/format_handler'

  # Declare that the including class indirects its methods to
  # this terminus.  The terminus name must be the name of a Puppet
  # default, not the value -- if it's the value, then it gets
  # evaluated at parse time, which is before the user has had a chance
  # to override it.
  def indirects(name, options = {})
    raise(ArgumentError, "Already handling indirection for #{@indirection.name}; cannot also handle #{name}") if @indirection
    # populate this class with the various new methods
    extend ClassMethods
    include InstanceMethods
    include Puppet::Indirector::Envelope
    extend Puppet::Network::FormatHandler

    # instantiate the actual Terminus for that type and this name (:ldap, w/ args :node)
    # & hook the instantiated Terminus into this class (Node: @indirection = terminus)
    @model_name = name

    @cache_class    = options.delete(:cache_class)
    @terminus_class = options.delete(:terminus_class)

    @terminus_setting = options.delete(:terminus_setting)

    @indirection = Puppet::Indirector::Indirection.new(self, name)
  end

  module ClassMethods
    attr_reader :indirection

    def default_route
      @default_route ||= make_route( @terminus_class || terminus_name_from_setting, @cache_class )
    end

    def terminus_name_from_setting
      Puppet[ @terminus_setting ].to_sym
    end

    def make_route( terminus_name, cache_name = nil )
      main_route = Puppet::Indirector::Route.new( @model_name, terminus_name )
      if @cache_class
        caching_route = Puppet::Indirector::Route.new( @model_name, cache_name )
        Puppet::Indirector::CachingRoute.new( main_route, caching_route )
      else
        main_route
      end
    end

    def cache_class=(klass)
      @default_route = nil
      @cache_class = klass
    end

    def terminus_class=(klass)
      @default_route = nil
      @terminus_class = klass
    end

    def find(*args)
      default_route.find(*args)
    end

    def destroy(*args)
      default_route.destroy(*args)
    end

    def search(*args)
      default_route.search(*args)
    end
  end

  module InstanceMethods
    def save(key = nil)
      self.class.default_route.save key, self
    end
  end
end
