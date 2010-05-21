require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # The basic container class.  This object behaves almost identically
  # to a normal array except at initialization time.  Note that its name
  # is 'Expression::ArrayConstructor', rather than plain 'Expression::Array'; I had too many
  # bugs when it was just 'Expression::Array', because things like
  # 'object.is_a?(Array)' never behaved as I expected.
  class ArrayConstructor < Branch
    include Enumerable

    # Return a child by index.  Probably never used.
    def [](index)
      @children[index]
    end

    # Evaluate our children.
    def compute_denotation(scope)
      # Make a new array, so we don't have to deal with the details of
      # flattening and such
      items = []

      # First clean out any Expression::ExpressionArrays
      @children.each { |child|
        if child.instance_of?(Expression::ArrayConstructor)
          child.each do |ac|
            items << ac
          end
        else
          items << child
        end
      }

      rets = items.flatten.collect { |child|
        child.denotation(scope)
      }
      rets.reject { |o| o.nil? }
    end

    def push(*ary)
      ary.each { |child|
        #Puppet.debug "adding %s(%s) of type %s to %s" %
        #    [child, child.object_id, child.class.to_s.sub(/.+::/,''),
        #    self.object_id]
        @children.push(child)
      }

      self
    end

    def to_s
      "[" + @children.collect { |c| c.to_s }.join(', ') + "]"
    end
  end

  # A simple container class, containing the parameters for an object.
  # Used for abstracting the grammar declarations.  Basically unnecessary
  # except that I kept finding bugs because I had too many arrays that
  # meant completely different things.
  class ResourceInstance < ArrayConstructor; end
end
