require 'puppet'
require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  class ArithmeticOperator < Expression::Branch

    attr_accessor :operator, :lval, :rval

    # Returns a boolean which is the result of the boolean operation
    # of lval and rval operands
    def compute_denotation(scope)
      # evaluate the operands, should return a boolean value
      lval = @lval.denotation(scope)
      lval = Puppet::Parser::Scope.number?(lval)
      if lval == nil
        raise ArgumentError, "left operand of #{@operator} is not a number"
      end
      rval = @rval.denotation(scope)
      rval = Puppet::Parser::Scope.number?(rval)
      if rval == nil
        raise ArgumentError, "right operand of #{@operator} is not a number"
      end

      # compute result
      lval.send(@operator, rval)
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid arithmetic operator #{@operator}" unless %w{+ - * / << >>}.include?(@operator)
    end
  end
end
