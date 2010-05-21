require 'puppet'
require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  class BooleanOperator < Expression::Branch

    attr_accessor :operator, :lval, :rval

    # Returns a boolean which is the result of the boolean operation
    # of lval and rval operands
    def compute_denotation
      # evaluate the first operand, should return a boolean value
      lval = @lval.denotation

      # return result
      # lazy evaluate right operand
      case @operator
      when "and"
        if Puppet::Parser::Scope.true?(lval)
          rval = @rval.denotation
          Puppet::Parser::Scope.true?(rval)
        else # false and false == false
          false
        end
      when "or"
        if Puppet::Parser::Scope.true?(lval)
          true
        else
          rval = @rval.denotation
          Puppet::Parser::Scope.true?(rval)
        end
      end
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid boolean operator #{@operator}" unless %w{and or}.include?(@operator)
    end
  end
end
