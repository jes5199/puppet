class Puppet::Indirector::Route
  attr :terminus_class
  attr :model
  def initialize( model, terminus_name )
    @model = model
    raise ArgumentError, "Invalid terminus name #{terminus_name.inspect}" unless terminus_name and terminus_name.to_s != ""
    @terminus_class = Puppet::Indirector::Terminus.terminus_class(model, terminus_name)
    raise ArgumentError, "Could not find terminus #{terminus_name} for indirection #{model}" unless @terminus_class
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

  private
  def terminus
    @terminus ||= @terminus_class.new
  end

end
