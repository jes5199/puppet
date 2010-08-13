class Puppet::Util::Settings::Validator
  def initialize(definitions, store)
    @definitions = definitions
    @store = store
  end

  def [](key)
    store[key]
  end

  def validate(key, value)

  def []=(key,value)
    raise "no such setting $#{key}" if ! @definitions[key]
    raise "no such setting $#{key}" if ! @definitions[key].valid? value
    store[key] = value
  end
end
