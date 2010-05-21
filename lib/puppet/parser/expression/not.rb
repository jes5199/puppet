require 'puppet'
require 'puppet/parser/expression/branch'

# An object that returns a boolean which is the boolean not
# of the given value.
class Puppet::Parser::Expression
  class Not < Expression::Branch
    attr_accessor :value

    def evaluate(scope)
      val = @value.safeevaluate(scope)
      ! Puppet::Parser::Scope.true?(val)
    end
  end
end
