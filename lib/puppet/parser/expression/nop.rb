require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # This class is a no-op, it doesn't produce anything
  # when evaluated, hence it's name :-)
  class Nop < Expression::Leaf
    def evaluate(scope)
      # nothing to do
    end
  end
end
