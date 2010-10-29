require 'puppet/util/docs'
require 'puppet/indirector/envelope'
require 'puppet/indirector/request'
require 'puppet/indirector/route'
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

  def initialize(model, name)
    @model = model
    @name  = name

    raise(ArgumentError, "Indirection #{@name} is already defined") if @@indirections.find { |i| i.name == @name }
    @@indirections << self
  end

end
