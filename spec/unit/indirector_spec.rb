#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, " when available to a model" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
    end
  end

  it "should provide a way for the model to register an indirection under a name" do
    @thingie.should respond_to(:indirects)
  end
end

describe Puppet::Indirector, "when registering an indirection" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end
  end

  it "should require a name when registering a model" do
    Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
  end

  it "should create an indirection instance to manage each indirecting model" do
    @indirection = @thingie.indirects(:test)
    @indirection.should be_instance_of(Puppet::Indirector::Indirection)
  end

  it "should not allow a model to register under multiple names" do
    # Keep track of the indirection instance so we can delete it on cleanup
    @indirection = @thingie.indirects :first
    Proc.new { @thingie.indirects :second }.should raise_error(ArgumentError)
  end

  it "should make the indirection available via an accessor" do
    @indirection = @thingie.indirects :first
    @thingie.indirection.should equal(@indirection)
  end

  it "should pass self and name to indirection" do
    klass = mock 'terminus class'
    Puppet::Indirector::Indirection.expects(:new).with(@thingie, :first, :some => :options)
    @indirection = @thingie.indirects :first, :some => :options
  end

  it "should extend the class with the Format Handler" do
    @indirection = @thingie.indirects :first
    @thingie.singleton_class.ancestors.should be_include(Puppet::Network::FormatHandler)
  end

  after do
    @indirection.delete if @indirection
  end
end

describe Puppet::Indirector, "when redirecting a model" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end
    @indirection = @thingie.send(:indirects, :test)
  end

  it "should include the Envelope module in the model" do
    @thingie.ancestors.should be_include(Puppet::Indirector::Envelope)
  end

  it "should give the model the ability to set the indirection terminus class" do
    terminus = Class.new
    Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :myterm).returns( terminus )
    @thingie.terminus_class = :myterm
    @thingie.default_route.terminus_class.should == terminus
  end

  it "should give the model the ability to set the indirection cache class" do
    main_terminus = Class.new
    cache_terminus = Class.new
    Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :myterm).returns( main_terminus )
    Puppet::Indirector::Terminus.expects(:terminus_class).with(:test, :mycache).returns( cache_terminus )
    @thingie.terminus_class = :myterm
    @thingie.cache_class = :mycache
    @thingie.default_route.cache_route.terminus_class.should == cache_terminus
  end

  after do
    @indirection.delete
  end
end
