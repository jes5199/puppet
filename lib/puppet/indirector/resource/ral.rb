class Puppet::Resource::Ral < Puppet::Indirector::Code
    def find( request )
        # find by name
        obj   = type(request).instances.find { |o| o.name == resource_name(request) } 
        obj ||= type(request).new(:name => resource_name(request), :check => type(request).properties.collect { |s| s.name })

        return obj.to_resource
    end

    def search( request )
        conditions = request.options.dup
        conditions[:name] = resource_name(request) if resource_name(request)

        type(request).instances.map do |obj|
            obj.to_resource
        end.find_all do |obj|
            conditions.all? {|property, value| obj.to_resource[property] == value.to_sym}
        end.sort do |a,b|
            a.title <=> b.title
        end
    end

    def save( request )
        # In RAL-land, to "save" means to actually try to change machine state
        obj = request.instance

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource obj.to_ral
        catalog.apply

        return obj.to_resource
    end

    private

    def type_name( request )
        request.key.split('/')[0]
    end

    def resource_name( request )
        request.key.split('/')[1]
    end

    def type( request )
        Puppet::Type.type(type_name(request)) or raise Puppet::Error "Could not find type #{type}"
    end
end
