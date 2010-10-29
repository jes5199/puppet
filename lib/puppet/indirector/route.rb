class Puppet::Indirector::Route
  attr :terminus_class
  attr :model
  def initialize( model, terminus )
    @model = model
    #@model_class    = Puppet::Indirector::Indirection.model(model)
    @terminus_class = Puppet::Indirector::Terminus.terminus_class(model, terminus)
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
