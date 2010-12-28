require 'puppet'

class Puppet::Util::LegacyProviderAdaptor
  attr_reader :provider

  def initialize( provider )
    @provider = provider
  end

  def features
    %w[ features get list set create destroy ]
  end

  def set( key, noop, properties, known_state = {} )
    resource = provider.new( key.merge( properties ).merge( "noop" => noop ) )

    harness = Puppet::Transaction::ResourceHarness.new

    changes = []
    status = harness.evaluate( true, resource )
    
    event_keys = %w[property desired_value previous_value message]
    return status.events.map{|e| e.to_pson_data_hash.reject{|event_key, event_data| !event_keys.include?(event_key) }}
  end

  def create( key, noop, properties, known_state = {} )
    resource = provider.new( {"ensure" => "present" }.merge( key ).merge( properties ).merge( "noop" => noop ) )

    harness = Puppet::Transaction::ResourceHarness.new

    changes = []
    status = harness.evaluate( true, resource )
    
    event_keys = %w[property desired_value message]
    return status.events.map{|e| e.to_pson_data_hash.reject{|event_key, event_data| !event_keys.include?(event_key) }}
  end

  def destroy( key, noop, known_state = {} )
    resource = provider.new( key.merge( "noop" => noop, "ensure" => :absent ) )

    harness = Puppet::Transaction::ResourceHarness.new

    changes = []
    status = harness.evaluate( true, resource )
    
    event_keys = %w[property previous_value message]
    return status.events.map{|e| e.to_pson_data_hash.reject{|event_key, event_data| !event_keys.include?(event_key) }}
  end

  def get( key, properties )
    provider.new( key.merge( :audit => properties ) ).to_resource.to_hash.reject{|prop, val| ! properties.include?(prop.to_s) }
  end

  def list( properties )
    # XXX: I can't seem to supress the audit :all that gets set in the type
    provider.instances.map{|x| x[:audit] = properties ; x.to_resource.to_hash.reject{|prop, val| ! properties.include?(prop) } }
  end

  def recurse( key, depth, properties )
    # XXX: file is a poor example of this.
    raise "not implemented"
  end

  def act( expression )
    verb   = expression[0]
    params = expression[1..-1] 
    case verb
      when "features": features( *params )
      when "get"     : get(      *params )
      when "list"    : list(     *params )
      when "set"     : set(      *params )
      when "create"  : create(   *params )
      when "destroy" : destroy(  *params )
    end
  end

  def parse_and_act( str )
    data = PSON.parse(str)
    act( data ).to_pson
  end

  def parse_and_run_from_stdin
    # TODO: legacy providers talk directly to the Puppet singleton to report errors
    #       This is not ideal.
    input = STDIN.read
    puts parse_and_act( input )
  end
end

