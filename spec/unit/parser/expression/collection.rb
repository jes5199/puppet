#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::Collection do
  before :each do
    @scope = stub_everything 'scope'
    @compiler = stub_everything 'compile'
    @scope.stubs(:compiler).returns(@compiler)

    @overrides = stub_everything 'overrides'
    @overrides.stubs(:is_a?).with(Puppet::Parser::Expression).returns(true)

  end

  it "should evaluate its query" do
    query = mock 'query'
    collection = Puppet::Parser::Expression::Collection.new :scope => ((@scope)), :query => query, :form => :virtual

    query.expects(:denotation)

    collection.compute_denotation
  end

  it "should instantiate a Collector for this type" do
    collection = Puppet::Parser::Expression::Collection.new :scope => ((@scope)), :form => :virtual, :type => "test"

    Puppet::Parser::Collector.expects(:new).with(@scope, "test", nil, nil, :virtual)

    collection.compute_denotation
  end

  it "should tell the compiler about this collector" do
    collection = Puppet::Parser::Expression::Collection.new :scope => ((@scope)), :form => :virtual, :type => "test"
    Puppet::Parser::Collector.stubs(:new).returns("whatever")

    @compiler.expects(:add_collection).with("whatever")

    collection.compute_denotation
  end

  it "should evaluate overriden paramaters" do
    collector = stub_everything 'collector'
    collection = Puppet::Parser::Expression::Collection.new :scope => ((@scope)), :form => :virtual, :type => "test", :override => @overrides
    Puppet::Parser::Collector.stubs(:new).returns(collector)

    @overrides.expects(:denotation)

    collection.compute_denotation
  end

  it "should tell the collector about overrides" do
    collector = mock 'collector'
    collection = Puppet::Parser::Expression::Collection.new :scope => ((@scope)), :form => :virtual, :type => "test", :override => @overrides
    Puppet::Parser::Collector.stubs(:new).returns(collector)

    collector.expects(:add_override)

    collection.compute_denotation
  end


end
