require 'puppet/parser/expression'
require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression::ResourceReference < Puppet::Parser::Expression::Branch
  attr_accessor :title, :type

  # Evaluate our object, but just return a simple array of the type
  # and name.
  def compute_denotation(scope)
    titles = Array(title.denotation(scope)).collect { |t| Puppet::Resource.new(type, t, :namespaces => scope.namespaces) }
    return(titles.length == 1 ? titles.pop : titles)
  end

  def to_s
    if title.is_a?(Puppet::Parser::Expression::ArrayConstructor)
      "#{type.to_s.capitalize}#{title}"
    else
      "#{type.to_s.capitalize}[#{title}]"
    end
  end
end
