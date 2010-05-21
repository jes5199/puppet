require 'puppet/parser/expression'
require 'puppet/parser/expression/branch'
require 'puppet/parser/relationship'

class Puppet::Parser::Expression::Relationship < Puppet::Parser::Expression::Branch
  RELATIONSHIP_TYPES = %w{-> <- ~> <~}

  attr_accessor :left, :right, :arrow, :type

  def actual_left
    chained? ? left.right : left
  end

  # Evaluate our object, but just return a simple array of the type
  # and name.
  def compute_denotation(scope)
    if chained?
      real_left = left.denotation(scope)
      left_dep = left_dep.shift if left_dep.is_a?(Array)
    else
      real_left = left.denotation(scope)
    end
    real_right = right.denotation(scope)

    source, target = sides2edge(real_left, real_right)
    result = Puppet::Parser::Relationship.new(source, target, type)
    scope.compiler.add_relationship(result)
    real_right
  end

  def initialize(left, right, arrow, args = {})
    super(args)
    unless RELATIONSHIP_TYPES.include?(arrow)
      raise ArgumentError, "Invalid relationship type #{arrow.inspect}; valid types are #{RELATIONSHIP_TYPES.collect { |r| r.to_s }.join(", ")}"
    end
    @left, @right, @arrow = left, right, arrow
  end

  def type
    subscription? ? :subscription : :relationship
  end

  def sides2edge(left, right)
    out_edge? ? [left, right] : [right, left]
  end

  private

  def chained?
    left.is_a?(self.class)
  end

  def out_edge?
    ["->", "~>"].include?(arrow)
  end

  def subscription?
    ["~>", "<~"].include?(arrow)
  end
end
