module Puppet
    module Util
        module CommandLine
            def self.shift_subcommand_from_argv( argv = ARGV, stdin = STDIN )
                if ! argv.first
                    "apply" unless stdin.tty? # ttys get usage info
                elsif argv.first == "--help"
                    # help should give you usage, not the help for `puppet apply`
                    nil
                elsif argv.first =~ /^-|\.pp$|\.rb$/
                    "apply"
                else
                    argv.shift
                end
            end
        end
    end
end
