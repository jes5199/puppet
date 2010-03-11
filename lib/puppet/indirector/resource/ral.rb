class Puppet::Resource::Ral < Puppet::Indirector::Code
    def find( request )
        # find by name
        obj   = type(request).instances.find { |o| o.name == resource_name(request) } 
        obj ||= type(request).new(:name => resource_name(request), :check => type(request).properties.collect { |s| s.name })

        return obj.to_resource
    end

    def search( request )
        type(request).instances.collect do |obj|
            obj.to_resource
        end
    end

    def save( request )
        obj = find(request)

        unless params.empty?
            params.each do |param, value|
                obj[param] = value
            end
            catalog = Puppet::Resource::Catalog.new
            catalog.add_resource obj
            begin
                catalog.apply
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
            end

        end

        #TODO: return
        [format.call(obj.to_trans(true))]
        return model.new
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
