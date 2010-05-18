#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }


require 'puppet/util/command_line'

describe Puppet::Util::CommandLine do
    before do
        @tty  = stub("tty",  :tty? => true )
        @pipe = stub("pipe", :tty? => false)
    end

    it "should pull off the first argument if it looks like a subcommand" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w( client --help whatever.pp ), @tty )

        command_line.subcommand_name.should == "client"
        command_line.args.should            == %w( --help whatever.pp )
    end

    it "should use 'apply' if the first argument looks like a .pp file" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w( whatever.pp ), @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w( whatever.pp )
    end

    it "should use 'apply' if the first argument looks like a .rb file" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w( whatever.rb ), @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w( whatever.rb )
    end

    it "should use 'apply' if the first argument looks like a flag" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w( --debug ), @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w( --debug )
    end

    it "should use 'apply' if the first argument is -" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w( - ), @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w( - )
    end

    it "should return nil if the first argument is --help" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w( --help ), @tty )

        command_line.subcommand_name.should == nil
    end


    it "should return nil if there are no arguments on a tty" do
        command_line = Puppet::Util::CommandLine.new("puppet", [], @tty )

        command_line.subcommand_name.should == nil
        command_line.args.should            == []
    end

    it "should use 'apply' if there are no arguments on a pipe" do
        command_line = Puppet::Util::CommandLine.new("puppet", [], @pipe )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == []
    end

    it "should return the executable name if it is not puppet" do
        command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], @tty )

        command_line.subcommand_name.should == "puppetmasterd"
    end

    it "should translate subcommand names into their legacy equivalent" do
        command_line = Puppet::Util::CommandLine.new("puppet", ["master"], @tty)
        command_line.legacy_executable_name.should == "puppetmasterd"
    end

    it "should leave legacy command names alone" do
        command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], @tty)
        command_line.legacy_executable_name.should == "puppetmasterd"
    end

    it "should provide a convenience method that only returns the subcommand" do
        Puppet::Util::CommandLine.expects(:subcommand_and_args).with("puppet", [], @pipe ).returns(["command", ['args']])
        command = Puppet::Util::CommandLine.subcommand_name( "puppet", [], @pipe )
        command.should == "command"
    end

    it "should provide a convenience method that only returns the args" do
        Puppet::Util::CommandLine.expects(:subcommand_and_args).with("puppet", [], @pipe ).returns(["command", ['args']])
        args = Puppet::Util::CommandLine.args( "puppet", [], @pipe )
        args.should == ['args']
    end

    it "should return the executable name if it is not puppet" do
        command, args = Puppet::Util::CommandLine.subcommand_and_args("puppetmasterd", [], @tty )

        command.should == "puppetmasterd"
    end

    it "should translate subcommand names into their legacy equivalent" do
        Puppet::Util::CommandLine.legacy_executable_name("puppet", ["master"], @tty).should == "puppetmasterd"
    end

    it "should leave legacy command names alone" do
        Puppet::Util::CommandLine.legacy_executable_name("puppetmasterd", [], @tty).should == "puppetmasterd"
    end

    describe "when instantiated" do
        it "should provide the results of subcommand and args" do
            Puppet::Util::CommandLine.expects(:subcommand_and_args).with("puppet", [], @pipe).returns(["command", ['args']])
            commandline = Puppet::Util::CommandLine.new("puppet", [], @pipe)

            commandline.subcommand_name.should == 'command'
            commandline.args.should == ['args']
        end

        it "should provide the legacy executable name" do
            Puppet::Util::CommandLine.expects(:subcommand_and_args).with("puppet", ['master'], @pipe).returns(["master", []])
            commandline = Puppet::Util::CommandLine.new("puppet", ['master'], @pipe)

            commandline.legacy_executable_name.should == 'puppetmasterd'
        end
    end

end
