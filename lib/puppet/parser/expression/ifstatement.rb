require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # A basic 'if/elsif/else' statement.
  class IfStatement < Expression::Branch

    associates_doc

    attr_accessor :test, :else, :statements

    # Short-curcuit evaluation.  If we're true, evaluate our statements,
    # else if there's an 'else' setting, evaluate it.
    # the first option that matches.
    def compute_denotation(scope)
      level = scope.ephemeral_level
      value = @test.denotation(scope)

      # let's emulate a new scope for each branches
      begin
        if Puppet::Parser::Scope.true?(value)
          return @statements.denotation(scope)
        else
          return defined?(@else) ? @else.denotation(scope) : nil
        end
      ensure
        scope.unset_ephemeral_var(level)
      end
    end
  end
end
