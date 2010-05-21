require 'puppet'
require 'puppet/parser/expression/branch'

# An object that returns a boolean which is the boolean not
# of the given value.
class Puppet::Parser::Expression
  class Minus < Expression::Branch
    attr_accessor :value

    def compute_denotation(scope)
      val = @value.denotation(scope)
      val = Puppet::Parser::Scope.number?(val)
      if val == nil
        raise ArgumentError, "minus operand #{val} is not a number"
      end
      -val
    end
  end
end
