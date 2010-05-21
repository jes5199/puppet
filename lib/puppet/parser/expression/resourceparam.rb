require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # The Expression node for the parameters inside ResourceDefs and Selectors.
  class ResourceParam < Expression::Branch
    attr_accessor :value, :param, :add

    # Return the parameter and the value.
    def compute_denotation

            return Puppet::Parser::Resource::Param.new(
                
        :name => @param,
        :value => @value.denotation,
        
        :source => scope.source, :line => self.line, :file => self.file,
        :add => self.add
      )
    end

    def to_s
      "#{@param} => #{@value.to_s}"
    end
  end
end
