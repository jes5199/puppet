require 'puppet/network/http/api'

module Puppet::Network::HTTP::API::V1
    # How we map http methods and the indirection name in the URI
    # to an indirection method.
    METHOD_MAP = {
        "GET" => {
            :plural => :search,
            :singular => :find
        },
        "PUT" => {
            :singular => :save
        },
        "DELETE" => {
            :singular => :destroy
        }
    }

    def uri2indirection(http_method, uri, params)
        uri = URI.parse(uri)
        indirection_name = indirection_from(uri)
        environment = environment_from(uri)
        key = key_from(uri)

        raise ArgumentError, "The environment must be purely alphanumeric, not '%s'" % environment unless environment =~ /^\w+$/
        raise ArgumentError, "The indirection name must be purely alphanumeric, not '%s'" % indirection_name unless indirection_name =~ /^\w+$/
        raise ArgumentError, "No request key specified in %s" % uri if key == "" or key.nil?

        method = indirection_method(http_method, indirection_name)
        params[:environment] = environment

        Puppet::Indirector::Request.new(indirection_name, method, key, params)
    end

    def indirection2uri(request)
        indirection_name = pluralized_indirection_name(request)
        '/' + [request.environment, indirection_name, request.escaped_key, request.query_string].join('/')
    end

    def indirection_method(http_method, indirection_name)
        unless METHOD_MAP[http_method]
            raise ArgumentError, "No support for http method %s" % http_method
        end

        unless method = METHOD_MAP[http_method][plurality(indirection_name)]
            raise ArgumentError, "No support for plural %s operations" % http_method
        end

        return method
    end

    def pluralized_indirection_name(request)
        return request.indirection_name unless request.method == :search

        indirection_name = request.indirection_name

        return "statuses" if indirection_name == "status"
        return indirection_name + "s"
    end

    def plurality(indirection_name)
        # NOTE This specific hook for facts is ridiculous, but it's a *many*-line
        # fix to not need this, and our goal is to move away from the complication
        # that leads to the fix being too long.
        return :singular if indirection_name == "facts"

        # "status" really is singular
        return :singular if indirection_name == "status"

        result = (indirection_name =~ /s$/) ? :plural : :singular

        indirection_name.sub!(/s$/, '') if result

        result
    end


    # Parse the key as a URI, setting attributes appropriately.
    def key_from(uri)
        return URI.unescape(uri.path) if uri.scheme == "file"
        return URI.unescape(uri.path.sub(/^\//, '')) if uri.scheme == 'puppet'

        URI.unescape(uri.path.sub(/^\//, '')).split('/',3)[2] || ''
    end

    def environment_from(uri)
        URI.unescape(uri.path.sub(/^\//, '')).split('/').first
    end

    def indirection_from(uri)
        URI.unescape(uri.path.sub(/^\//, '')).split('/',3)[1]
    end

end
