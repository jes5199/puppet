require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # The inline conditional operator.  Unlike CaseStatement, which executes
  # code, we just return a value.
  class Selector < Expression::Branch
    attr_accessor :param, :values

    # Find the value that corresponds with the test.
    def compute_denotation(scope)
      level = scope.ephemeral_level
      # Get our parameter.
      paramvalue = @param.denotation(scope)

      default = nil

      @values = [@values] unless @values.instance_of? Expression::ArrayConstructor or @values.instance_of? Array

      # Then look for a match in the options.
      @values.each do |obj|
        # short circuit asap if we have a match
        return obj.value.denotation(scope) if obj.param.evaluate_match(paramvalue, scope)

        # Store the default, in case it's necessary.
        default = obj if obj.param.is_a?(Default)
      end

      # Unless we found something, look for the default.
      return default.value.denotation(scope) if default

      self.fail Puppet::ParseError, "No matching value for selector param '#{paramvalue}'"
    ensure
      scope.unset_ephemeral_var(level)
    end

    def to_s
      param.to_s + " ? { " + values.collect { |v| v.to_s }.join(', ') + " }"
    end
  end
end
