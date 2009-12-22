#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/rails'

describe Puppet::Rails, "when initializing any connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    before do
        Puppet.settings.stubs(:use)
        @logger = mock 'logger'
        @logger.stub_everything
        Logger.stubs(:new).returns(@logger)

        ActiveRecord::Base.stubs(:logger).returns(@logger)
        ActiveRecord::Base.stubs(:connected?).returns(false)
    end

    it "should use settings" do
        Puppet.settings.expects(:use).with(:main, :rails, :puppetmasterd)

        Puppet::Rails.connect
    end

    it "should set up a logger with the appropriate Rails log file" do
        logger = mock 'logger'
        Logger.expects(:new).with(Puppet[:railslog]).returns(logger)
        ActiveRecord::Base.expects(:logger=).with(logger)

        Puppet::Rails.connect
    end

    it "should set the log level to whatever the value is in the settings" do
        Puppet.settings.stubs(:use)
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("debug")
        Puppet.settings.stubs(:value).with(:railslog).returns("/my/file")
        logger = mock 'logger'
        Logger.stubs(:new).returns(logger)
        ActiveRecord::Base.stubs(:logger).returns(logger)
        logger.expects(:level=).with(Logger::DEBUG)

        ActiveRecord::Base.stubs(:allow_concurrency=)
        ActiveRecord::Base.stubs(:verify_active_connections!)
        ActiveRecord::Base.stubs(:establish_connection)
        Puppet::Rails.stubs(:database_arguments).returns({})

        Puppet::Rails.connect
    end

    describe "on ActiveRecord 2.1.x" do
        confine "ActiveRecord 2.1.x" => (::ActiveRecord::VERSION::MAJOR == 2 and ::ActiveRecord::VERSION::MINOR <= 1)

        it "should set ActiveRecord::Base.allow_concurrency" do
            ActiveRecord::Base.expects(:allow_concurrency=).with(true)

            Puppet::Rails.connect
        end
    end

    it "should call ActiveRecord::Base.verify_active_connections!" do
        ActiveRecord::Base.expects(:verify_active_connections!)

        Puppet::Rails.connect
    end

    it "should call ActiveRecord::Base.establish_connection with database_arguments" do
        Puppet::Rails.expects(:database_arguments).returns({})
        ActiveRecord::Base.expects(:establish_connection)

        Puppet::Rails.connect
    end
end

class RailsTesting
    PARAMETER_MAP = {:adapter => :dbadapter, :log_level => :rails_loglevel, :host => :dbserver, :username => :dbuser, :password => :dbpassword,
        :database => :dbname, :socket => :dbsocket, :pool => :dbconnections}
end

describe Puppet::Rails, "when initializing a sqlite3 connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?
    before do
        Puppet[:dbadapter] = "sqlite3"
    end

    [:adapter, :log_level].each do |param|
        name = RailsTesting::PARAMETER_MAP[param]
        it "should provide the #{param} as the #{name} setting" do
            Puppet::Rails.database_arguments[param].should == Puppet[name]
        end
    end

    it "should provide the dbfile setting as the name for the database" do
        Puppet::Rails.database_arguments[:database].should == Puppet[:dblocation]
    end
end

describe Puppet::Rails, "when initializing a mysql connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    before do
        Puppet[:dbadapter] = "mysql"
    end

    [:adapter, :log_level, :host, :username, :password, :database].each do |param|
        name = RailsTesting::PARAMETER_MAP[param]
        it "should provide the #{param} from the '#{name}' setting" do
            Puppet::Rails.database_arguments[param].should == Puppet[name]
        end
    end

    it "should set the socket from the 'dbsocket' setting if a value is provided" do
        Puppet[:dbsocket] = "foo"
        Puppet::Rails.database_arguments[:socket].should == "foo"
    end

    it "should set the pool to the 'dbconnections' setting if the connection count is greater than zero" do
        Puppet[:dbconnections] = "2"
        Puppet::Rails.database_arguments[:pool].should == 2
    end
end

describe Puppet::Rails, "when initializing a postgresql connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?
    before do
        Puppet[:dbadapter] = "postgresql"
    end

    [:adapter, :log_level, :host, :username, :password, :database].each do |param|
        name = RailsTesting::PARAMETER_MAP[param]
        it "should provide the #{param} from the '#{name}' setting" do
            Puppet::Rails.database_arguments[param].should == Puppet[name]
        end
    end

    it "should set the socket from the 'dbsocket' setting if a value is provided" do
        Puppet[:dbsocket] = "foo"
        Puppet::Rails.database_arguments[:socket].should == "foo"
    end
end

describe Puppet::Rails, "when initializing an Oracle connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?
    before do
        Puppet[:dbadapter] = "oracle_enhanced"
    end

    [:adapter, :log_level, :username, :password, :database].each do |param|
        name = RailsTesting::PARAMETER_MAP[param]
        it "should provide the #{param} from the '#{name}' setting" do
            Puppet::Rails.database_arguments[param].should == Puppet[name]
        end
    end
end
