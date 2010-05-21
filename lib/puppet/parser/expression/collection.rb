require 'puppet'
require 'puppet/parser/expression/branch'
require 'puppet/parser/collector'

# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::Expression
class Collection < Expression::Branch
  attr_accessor :type, :query, :form
  attr_reader :override

  associates_doc

  # We return an object that does a late-binding evaluation.
  def evaluate(scope)
    if self.query
      str, code = self.query.safeevaluate scope
    else
      str = code = nil
    end

    newcoll = Puppet::Parser::Collector.new(scope, @type, str, code, self.form)

    scope.compiler.add_collection(newcoll)

    # overrides if any
    # Evaluate all of the specified params.
    if @override
      params = @override.collect do |param|
        param.safeevaluate(scope)
      end


            newcoll.add_override(
                
        :parameters => params,
        :file => @file,
        :line => @line,
        :source => scope.source,
        
        :scope => scope
      )
    end

    newcoll
  end

  # Handle our parameter ourselves
  def override=(override)
    if override.is_a?(Expression::ArrayConstructor)
      @override = override
    else

            @override = Expression::ArrayConstructor.new(
                
        :line => override.line,
        :file => override.file,
        
        :children => [override]
      )
    end
  end

end
end
