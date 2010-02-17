Puppet::Type.type(:file).provide :win32 do
    desc "Uses Win32 functionality to manage file's users and rights."

    confine :feature => :win32

    include Puppet::Util::Warnings

    require 'sys/admin'
    
    def id2name(id)
        return id.to_s if id.is_a?(Symbol)
        return nil if id > Puppet[:maximum_uid].to_i
        # should translate ID numbers to usernames
        return id
    end

    def insync?(current, should)
        return true unless should

        should.each do |value|
            if value =~ /^\d+$/
                uid = Integer(value)
            elsif value.is_a?(String)
                fail "Could not find user %s" % value unless uid = uid(value)
            else
                uid = value
            end

            return true if uid == current
        end

        unless Puppet.features.root?
            warnonce "Cannot manage ownership unless running as root"
            return true
        end

        return false
    end

    # Determine if the user is valid, and if so, return the UID
    def validuser?(value)
        info "Is '%s' a valid user?" % value
        return 0
        begin
            number = Integer(value)
            return number
        rescue ArgumentError
            number = nil
        end
        if number = uid(value)
            return number
        else
            return false
        end
    end

    def retrieve(resource)
        unless stat = resource.stat(false)
            return :absent
        end

        currentvalue = stat.uid

        # On OS X, files that are owned by -2 get returned as really
        # large UIDs instead of negative ones.  This isn't a Ruby bug,
        # it's an OS X bug, since it shows up in perl, too.
        if currentvalue > Puppet[:maximum_uid].to_i
            self.warning "Apparently using negative UID (%s) on a platform that does not consistently handle them" % currentvalue
            currentvalue = :silly
        end

        return currentvalue
    end

    def sync(path, links, should)
        info("should set '%s'%%owner to '%s'" % [path, should])
    end
end
