require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # A separate ElseIf statement; can function as an 'else' if there's no
  # test.
  class Else < Expression::Branch

    associates_doc

    attr_accessor :statements

    # Evaluate the actual statements; this only gets called if
    # our test was true matched.
    def compute_denotation(scope)
      @statements.denotation(scope)
    end
  end
end
