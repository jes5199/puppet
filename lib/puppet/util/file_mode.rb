require 'puppet/util/octal'
module Puppet::Util::FileMode
  def self.symbolic_mode_pattern
    /^([ugoa]+)([+-])([rwxstX]+|[ugo])$/
  end

  def self.valid?(modification)
    modification =~ /^[0-7]+$/ || modification.split(/,/).inject(true){|acc, part| acc and part =~ Puppet::Util::FileMode.symbolic_mode_pattern }
  end

  def self.normalize(modification)
    if modification =~ /^[0-7]+$/
      Puppet::Util::Octal.octalForInteger( Puppet::Util::Octal.integerForOctal( modification ) )
    else
      modification
    end
  end

  def self.bits_for_mode(modification, mode = 0, is_directory = false)
    if modification =~ /^\d+$/
      return Puppet::Util::Octal.integerForOctal(modification)
    end

    who_masks = {
      'u' => 04700,
      'g' => 02070,
      'o' => 01007,
    }

    what_masks = {
      'r' => 00444,
      'w' => 00222,
      'x' => 00111,
      's' => 06000,
      't' => 01000,
    }

    shifts = {
      'u' => 6,
      'g' => 3,
      'o' => 0,
    }

    modification.split(/,/).each do |part|
      if part =~ symbolic_mode_pattern
        who, how, what = $1, $2, $3

        if who =~ /a/
          who = 'ugo'
        end

        old_mode = mode

        who.split(//).each do |who_letter|
          what.split(//).each do |what_letter|

            if what_letter =~ /[ugo]/
              from_shift = shifts[what_letter]
              to_shift   = shifts[who_letter]
              bits  = ( 7 << from_shift & old_mode ) >> from_shift
              value = bits << to_shift
            elsif what_letter == 'X'
              # if we have any executables or is_directory, then we set executable
              if is_directory or old_mode & what_masks['x'] > 0
                value = who_masks[who_letter] & what_masks['x']
              else
                value = 0
              end
            else
              value = who_masks[who_letter] & what_masks[what_letter]
            end

            if how == '+'
              mode |=  value
            else
              mode &= ~value
            end

          end
        end
      end
    end

    mode

  end
end
