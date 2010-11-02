#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/facts'

describe Puppet::Node::Facts, "when indirecting" do
  before do
    @facts = Puppet::Node::Facts.new("me")
  end

  it "should be able to convert all fact values to strings" do
    @facts.values["one"] = 1
    @facts.stringify
    @facts.values["one"].should == "1"
  end

  it "should add the node's certificate name as the 'clientcert' fact when adding local facts" do
    @facts.add_local_facts
    @facts.values["clientcert"].should == Puppet.settings[:certname]
  end

  it "should add the Puppet version as a 'clientversion' fact when adding local facts" do
    @facts.add_local_facts
    @facts.values["clientversion"].should == Puppet.version.to_s
  end

  it "should add the current environment as a fact if one is not set when adding local facts" do
    @facts.add_local_facts
    @facts.values["environment"].should == Puppet[:environment]
  end

  it "should not replace any existing environment fact when adding local facts" do
    @facts.values["environment"] = "foo"
    @facts.add_local_facts
    @facts.values["environment"].should == "foo"
  end

  it "should be able to downcase fact values" do
    Puppet.settings.stubs(:value).returns "eh"
    Puppet.settings.expects(:value).with(:downcasefacts).returns true

    @facts.values["one"] = "Two"

    @facts.downcase_if_necessary
    @facts.values["one"].should == "two"
  end

  it "should only try to downcase strings" do
    Puppet.settings.stubs(:value).returns "eh"
    Puppet.settings.expects(:value).with(:downcasefacts).returns true

    @facts.values["now"] = Time.now

    @facts.downcase_if_necessary
    @facts.values["now"].should be_instance_of(Time)
  end

  it "should not downcase facts if not configured to do so" do
    Puppet.settings.stubs(:value).returns "eh"
    Puppet.settings.expects(:value).with(:downcasefacts).returns false

    @facts.values["one"] = "Two"
    @facts.downcase_if_necessary
    @facts.values["one"].should == "Two"
  end

  describe "when indirecting" do
    before do
      @default_route = stub 'default_route', :request => mock('request'), :name => :facts

      @facts = Puppet::Node::Facts.new("me", "one" => "two")
    end

    it "should redirect to the specified fact store for retrieval" do
      Puppet::Node::Facts.stubs(:default_route).returns(@default_route)
      @default_route.expects(:find)
      Puppet::Node::Facts.find(:my_facts)
    end

    it "should redirect to the specified fact store for storage" do
      Puppet::Node::Facts.stubs(:default_route).returns(@default_route)
      @default_route.expects(:save)
      @facts.save
    end

    describe "when the Puppet application is 'master'" do
      it "should default to the 'yaml' terminus" do
        pending "Cannot test the behavior of defaults in defaults.rb"
        # Puppet::Node::Facts.indirection.terminus_class.should == :yaml
      end
    end

    describe "when the Puppet application is not 'master'" do
      it "should default to the 'facter' terminus" do
        pending "Cannot test the behavior of defaults in defaults.rb"
        # Puppet::Node::Facts.indirection.terminus_class.should == :facter
      end
    end

  end

  describe "when storing and retrieving" do
    it "should add metadata to the facts" do
      facts = Puppet::Node::Facts.new("me", "one" => "two", "three" => "four")
      facts.values[:_timestamp].should be_instance_of(Time)
    end

    describe "using pson" do
      before :each do
        @timestamp = Time.parse("Thu Oct 28 11:16:31 -0700 2010")
        @expiration = Time.parse("Thu Oct 28 11:21:31 -0700 2010")
      end

      it "should accept properly formatted pson" do
        pson = %Q({"name": "foo", "expiration": "#{@expiration}", "timestamp": "#{@timestamp}", "values": {"a": "1", "b": "2", "c": "3"}})
        format = Puppet::Network::FormatHandler.format('pson')
        facts = format.intern(Puppet::Node::Facts,pson)
        facts.name.should == 'foo'
        facts.expiration.should == @expiration
        facts.values.should == {'a' => '1', 'b' => '2', 'c' => '3', :_timestamp => @timestamp}
      end

      it "should generate properly formatted pson" do
        Time.stubs(:now).returns(@timestamp)
        facts = Puppet::Node::Facts.new("foo", {'a' => 1, 'b' => 2, 'c' => 3})
        facts.expiration = @expiration
        pson = PSON.parse(facts.to_pson)
        pson.should == {"name"=>"foo", "timestamp"=>@timestamp.to_s, "expiration"=>@expiration.to_s, "values"=>{"a"=>1, "b"=>2, "c"=>3}}
      end
    end
  end
end
