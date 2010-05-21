class Puppet::Parser::Expression
  # The parent class of all Expression nodes that contain other Expression nodes.
  # Everything but the really simple objects descend from this.  It is
  # important to note that Branch objects contain other Expression nodes only --
  # if you want to contain values, use a descendent of the Expression::Leaf class.
  class Branch < Expression
    include Enumerable
    attr_accessor :pin, :children

    # Initialize our object.  Largely relies on the method from the base
    # class, but also does some verification.
    def initialize(arghash)
      super(arghash)

      # Create the hash, if it was not set at initialization time.
      @children ||= []

      # Verify that we only got valid Expression nodes.
      @children.each { |child|
        unless child.is_a? Expression
          raise Puppet::DevError,
            "child #{child} is a #{child.class} instead of ast"
        end
      }
    end
  end
end
