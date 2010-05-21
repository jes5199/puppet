require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # The AST object for the parameters inside ResourceDefs and Selectors.
  class ResourceParam < AST::Branch
    attr_accessor :value, :param, :add

    # Return the parameter and the value.
    def evaluate(scope)

            return Puppet::Parser::Resource::Param.new(
                
        :name => @param,
        :value => @value.safeevaluate(scope),
        
        :source => scope.source, :line => self.line, :file => self.file,
        :add => self.add
      )
    end

    def to_s
      "#{@param} => #{@value.to_s}"
    end
  end
end
