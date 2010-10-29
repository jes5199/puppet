class Puppet::Indirector::CachingRoute
  def initialize( main_route, cache_route, options = {})
    @main_route  = main_route
    @cache_route = cache_route
    @ttl = options[:ttl]
  end

  def ttl
    @ttl || Puppet[:runinterval].to_i
  end

  def expiration
    Time.now + ttl
  end

  def terminus_class
    @main_route.terminus_class
  end

  def cache_terminus_class
    @cache_route.terminus_class
  end

  def find( key, options = {} )
    result = @cache_route.find( key, options )
    if result and result.respond_to?(:expired?) and ! result.expired?
      return result
    end

    result = @main_route.find( key, options )
    if result.respond_to?(:expiration=)
      result.expiration ||= expiration
    end
    @cache_route.save( key, result ) if result

    return result
  end

  def save( key, instance )
    @main_route.save(key, instance)
    @cache_route.save(key, instance)
  end

  def search( key, options = {} )
    @main_route.search(key, options)
  end

  def destroy( key, options = {} )
    @main_route.destroy(key, options)

    if @cache_route.find(key, options) # since destroy isn't idempotent
      @cache_route.destroy(key, options)
    end
  end
end
