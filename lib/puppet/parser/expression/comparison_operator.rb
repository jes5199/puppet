require 'puppet'
require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  class ComparisonOperator < Expression::Branch

    attr_accessor :operator, :lval, :rval

    # Returns a boolean which is the result of the boolean operation
    # of lval and rval operands
    def compute_denotation
      # evaluate the operands, should return a boolean value
      lval = @lval.denotation
      rval = @rval.denotation

      # convert to number if operands are number
      lval = Puppet::Parser::Scope.number?(lval) || lval
      rval = Puppet::Parser::Scope.number?(rval) || rval

      # return result
      unless @operator == '!='
        lval.send(@operator,rval)
      else
        lval != rval
      end
    end

    def initialize(hash)
      super

      raise ArgumentError, "Invalid comparison operator #{@operator}" unless %w{== != < > <= >=}.include?(@operator)
    end
  end
end
