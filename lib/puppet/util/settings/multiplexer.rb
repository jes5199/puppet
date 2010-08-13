class Puppet::Util::Settings::Multiplexer
  def initialize(storage_pairs)
    @precedence = storage_pairs.map{|pair| pair[0]} 
    @storage = storage_pairs.inject({}){|hash, pair| hash[pair[0]] = pair[1]}
    @write_layer = @precedence.first
  end

  def [](key)
    @precedence.inject(nil){ |val, name| val.nil? ? @storage[name][key] : val }
  end
  
  def []=(key, value)
    @storage[ @write_layer ][ key ] = value
  end

  def set_value(layer, key, value)
    raise "no such layer #{layer}" unless @storage[layer]
    @storage[ layer ][ key ] = value
  end
end
