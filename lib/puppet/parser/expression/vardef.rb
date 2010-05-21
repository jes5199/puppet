require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # Define a variable.  Stores the value in the current scope.
  class VarDef < Expression::Branch

    associates_doc

    attr_accessor :name, :value, :append

    

    # Look up our name and value, and store them appropriately.  The
    # lexer strips off the syntax stuff like '$'.
    def compute_denotation
      value = @value.denotation
      if name.is_a?(HashOrArrayAccess)
        name.assign(scope, value)
      else
        name = @name.denotation

        parsewrap do
          scope.setvar(name,value, :file => @file, :line => @line, :append => @append)
        end
      end
    end
  end
end
