# Manage file modes.  This state should support different formats
# for specification (e.g., u+rwx, or -0011), but for now only supports
# specifying the full mode.
require 'puppet/util/octal'
require 'puppet/util/file_mode'
module Puppet
  Puppet::Type.type(:file).newproperty(:mode) do
    require 'etc'
    desc "Mode the file should be.  Currently relatively limited:
      you must specify the exact mode the file should be.

      Note that when you set the mode of a directory, Puppet always
      sets the search/traverse (1) bit anywhere the read (4) bit is set.
      This is almost always what you want: read allows you to list the
      entries in a directory, and search/traverse allows you to access
      (read/write/execute) those entries.)  Because of this feature, you
      can recursively make a directory and all of the files in it
      world-readable by setting e.g.:

          file { '/some/dir':
            mode => 644,
            recurse => true,
          }

      In this case all of the files underneath `/some/dir` will have
      mode 644, and all of the directories will have mode 755."

    @event = :file_changed

    munge do |should|
      if should.is_a?(String)
        unless Puppet::Util::FileMode.valid?(should)
          raise Puppet::Error, "File modes must either be octal numbers or valid chmod patterns, not #{should.inspect}"
        end
        Puppet::Util::FileMode.normalize(should)
      else
        Puppet::Util::Octal.octalForInteger( should )
      end
    end

    # If we're a directory, we need to be executable for all cases
    # that are readable.  This should probably be selectable, but eh.
    def dirmask(value)
      if FileTest.directory?(@resource[:path]) and value =~ /^\d+$/
        value = Puppet::Util::Octal.integerForOctal(value)
        value |= 0100 if value & 0400 != 0
        value |= 010 if value & 040 != 0
        value |= 01 if value & 04 != 0
        value = Puppet::Util::Octal.octalForInteger(value)
      end

      value
    end

    def insync?(currentvalue)
      if stat = @resource.stat and stat.ftype == "link" and @resource[:links] != :follow
        self.debug "Not managing symlink mode"
        return true
      else
        return super(currentvalue)
      end
    end

    def property_matches?(desired, current)
      return false unless current
      current_bits = Puppet::Util::Octal.integerForOctal(current)
      desired_bits = Puppet::Util::FileMode.bits_for_mode(desired, current_bits, stat_is_directory?)
      desired_bits == current_bits
    end

    def retrieve
      # If we're not following links and we're a link, then we just turn
      # off mode management entirely.

      if has_stat?
        unless defined?(@fixed)
          @should &&= @should.collect { |s| self.dirmask(s) }
        end
        return Puppet::Util::Octal.octalForInteger(stat_mode & 007777)
      else
        return :absent
      end
    end

    def has_stat?
      @resource.stat(false)
    end

    def stat_mode
      @resource.stat.mode & 007777
    end

    def stat_is_directory?
      has_stat? and @resource.stat.directory?
    end

    def sync
      mode = self.should

      begin
        File.chmod(Puppet::Util::FileMode.bits_for_mode(mode, stat_mode, stat_is_directory?), @resource[:path])
      rescue => detail
        error = Puppet::Error.new("failed to chmod #{@resource[:path]}: #{detail.message}")
        error.set_backtrace detail.backtrace
        raise error
      end
      :file_changed
    end

    def change_to_s(old_value, change_value)
      if change_value =~ /^\d+$/
        super
      else
        old_bits = Puppet::Util::Octal.integerForOctal(old_value)
        new_bits = Puppet::Util::FileMode.bits_for_mode(change_value, old_bits, stat_is_directory?)
        new_value = Puppet::Util::Octal.octalForInteger(new_bits)
        super(old_value, new_value) + " (#{change_value})"
      end
    end
  end
end

