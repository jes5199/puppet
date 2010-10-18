module Puppet::Util::Octal
  def self.integerForOctal( str )
    Integer( "0" + str )
  end

  def self.octalForInteger( int )
    "%o" % int
  end
end
