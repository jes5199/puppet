# the parent class for all of our syntactical objects

require 'puppet'
require 'puppet/util/autoload'
require 'puppet/file_collection/lookup'

# The base class for all of the objects that make up the parse trees.
# Handles things like file name, line #, and also does the initialization
# for all of the parameters of all of the child objects.
class Puppet::Parser::Expression
  # Do this so I don't have to type the full path in all of the subclasses
  Expression = Puppet::Parser::Expression

  include Puppet::FileCollection::Lookup

  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper
  include Puppet::Util::Docs

  attr_accessor :parent, :scope

  # Yield each contained Expression node in turn.  Used mostly by evaluate.
  # This definition means that we don't have to override evaluate
  # every time.
  def each
    [(instance_variables-[@parent]).collect { |v| instance_variable_get(v) }].flatten.select { |x| yield x if x.is_a? Expression }
  end

  # don't fetch lexer comment by default
  def use_docs
    self.class.use_docs
  end

  # allow our subclass to specify they want documentation
  class << self
    attr_accessor :use_docs
    def associates_doc
    self.use_docs = true
    end
  end

  # Does this ast object set something?  If so, it gets evaluated first.
  def self.settor?
    if defined?(@settor)
      @settor
    else
      false
    end
  end

  # Evaluate the current object.  Just a stub method, since the subclass
  # should override this method.
  # of the contained children and evaluates them in turn, returning a
  # list of all of the collected values, rejecting nil values
  def evaluate(*options)
    raise Puppet::DevError, "Did not override #evaluate in #{self.class}"
  end

  # Throw a parse error.
  def parsefail(message)
    self.fail(Puppet::ParseError, message)
  end

  # Wrap a statemp in a reusable way so we always throw a parse error.
  def parsewrap
    exceptwrap :type => Puppet::ParseError do
      yield
    end
  end

  # The version of the evaluate method that should be called, because it
  # correctly handles errors.  It is critical to use this method because
  # it can enable you to catch the error where it happens, rather than
  # much higher up the stack.
  def safeevaluate(*options)
    # We duplicate code here, rather than using exceptwrap, because this
    # is called so many times during parsing.
    begin
      return self.evaluate(*options)
    rescue Puppet::Error => detail
      raise adderrorcontext(detail)
    rescue => detail
      error = Puppet::Error.new(detail.to_s)
      # We can't use self.fail here because it always expects strings,
      # not exceptions.
      raise adderrorcontext(error, detail)
    end
  end

  # Initialize the object.  Requires a hash as the argument, and
  # takes each of the parameters of the hash and calls the settor
  # method for them.  This is probably pretty inefficient and should
  # likely be changed at some point.
  def initialize(args)
    set_options(args)
  end
end

# And include all of the Expression node classes.
require 'puppet/parser/expression/arithmetic_operator'
require 'puppet/parser/expression/array'
require 'puppet/parser/expression/hash'
require 'puppet/parser/expression/branch'
require 'puppet/parser/expression/boolean_operator'
require 'puppet/parser/expression/caseopt'
require 'puppet/parser/expression/casestatement'
require 'puppet/parser/expression/collection'
require 'puppet/parser/expression/collexpr'
require 'puppet/parser/expression/comparison_operator'
require 'puppet/parser/expression/else'
require 'puppet/parser/expression/function'
require 'puppet/parser/expression/ifstatement'
require 'puppet/parser/expression/leaf'
require 'puppet/parser/expression/match_operator'
require 'puppet/parser/expression/minus'
require 'puppet/parser/expression/nop'
require 'puppet/parser/expression/not'
require 'puppet/parser/expression/resource'
require 'puppet/parser/expression/resource_defaults'
require 'puppet/parser/expression/resource_override'
require 'puppet/parser/expression/resource_reference'
require 'puppet/parser/expression/resourceparam'
require 'puppet/parser/expression/selector'
require 'puppet/parser/expression/tag'
require 'puppet/parser/expression/vardef'
require 'puppet/parser/expression/relationship'
