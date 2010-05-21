require 'puppet/parser/expression/branch'

class Puppet::Parser::Expression
  # The basic logical structure in Puppet.  Supports a list of
  # tests and statement arrays.
  class CaseStatement < Expression::Branch
    attr_accessor :test, :options, :default

    associates_doc

    # Short-curcuit evaluation.  Return the value of the statements for
    # the first option that matches.
    def compute_denotation(scope)
      level = scope.ephemeral_level

      value = @test.denotation(scope)

      retvalue = nil
      found = false

      # Iterate across the options looking for a match.
      default = nil
      @options.each do |option|
        option.eachopt do |opt|
          return option.denotation(scope) if opt.evaluate_match(value, scope)
        end

        default = option if option.default?
      end

      # Unless we found something, look for the default.
      return default.denotation(scope) if default

      Puppet.debug "No true answers and no default"
      return nil
    ensure
      scope.unset_ephemeral_var(level)
    end
  end
end
