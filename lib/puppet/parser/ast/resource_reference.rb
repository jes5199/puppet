require 'puppet/parser/ast'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST::ResourceReference < Puppet::Parser::AST::Branch
  attr_accessor :title, :type

  # Evaluate our object, but just return a simple array of the type
  # and name.
  def evaluate(scope)
    a_type = type
    titles = Array(title.safeevaluate(scope))

    case type.downcase
    when "class"
      titles = titles.collect do |a_title|  
        # resolve the a_title
        hostclass = scope.find_hostclass(a_title)
        if hostclass
          hostclass.name
        else
          a_title
        end
      end
    when "node"
      # nothing
    else
      # resolve the type
      resource_type = Puppet::Resource.new("notify", "bogus bogus bogus", :namespaces => scope.namespaces).find_resource_type(type)
      a_type = resource_type.name if resource_type
    end

    resources = titles.collect{ |a_title|
      p [a_type, a_title, scope.namespaces]
      Puppet::Resource.new(a_type, a_title)
    }

    return(resources.length == 1 ? resources.pop : resources)
  end

  def to_s
    if title.is_a?(Puppet::Parser::AST::ASTArray)
      "#{type.to_s.capitalize}#{title}"
    else
      "#{type.to_s.capitalize}[#{title}]"
    end
  end
end
