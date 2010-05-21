require 'puppet/parser/expression/leaf'

class Puppet::Parser::Expression
  class HashConstructor < Leaf
    include Enumerable

    # Evaluate our children.
    def evaluate(scope)
      items = {}

      @value.each_pair do |k,v|
        key = k.respond_to?(:safeevaluate) ? k.safeevaluate(scope) : k
        items.merge!({ key => v.safeevaluate(scope) })
      end

      items
    end

    def merge(hash)
      case hash
      when HashConstructor
        @value = @value.merge(hash.value)
      when Hash
        @value = @value.merge(hash)
      end
    end

    def to_s
      "{" + @value.collect { |v| v.collect { |a| a.to_s }.join(' => ') }.join(', ') + "}"
    end
  end
end
