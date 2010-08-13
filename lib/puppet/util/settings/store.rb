class Puppet::Util::Settings::Store
  def initialize
    @contents = Hash.new
  end

  def [](key)
    @contents[key]
  end

  def []=(key,value)
    @contents[key] = value
  end
end
