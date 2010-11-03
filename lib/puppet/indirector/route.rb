class Puppet::Indirector::Route
  attr :terminus
  attr :model
  def initialize( indirection, terminus_name )
    @model = indirection.name
    raise ArgumentError, "Invalid terminus name #{terminus_name.inspect}" unless terminus_name and terminus_name.to_s != ""
    @terminus = indirection.terminus(terminus_name)
    raise ArgumentError, "Could not find terminus #{terminus_name} for indirection #{model_name}" unless @terminus
  end

  def find( key, options = {} )
    request = Puppet::Indirector::Request.new(model, :find, key, options)
    terminus.find( request )
  end

  def save( key, instance )
    request = Puppet::Indirector::Request.new(model, :save, key, instance)
    terminus.save( request )
  end

  def search( key, options = {} )
    request = Puppet::Indirector::Request.new(model, :search, key, options)
    terminus.search( request )
  end

  def destroy( key, options = {} )
    request = Puppet::Indirector::Request.new(model, :destroy, key, options)
    terminus.destroy( request )
  end
  
  def terminus_class
    terminus.class
  end

end
