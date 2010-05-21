#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::Resource do
  ast = Puppet::Parser::Expression

  before :each do
    @title = Puppet::Parser::Expression::String.new(:scope => ((@scope)), :value => "mytitle")
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new(:compiler => @compiler)
    @scope.stubs(:resource).returns(stub_everything)
    @resource = Puppet::Parser::Expression::Resource.new(:scope => ((@scope)), :title => @title, :type => "file", :parameters => Puppet::Parser::Expression::ArrayConstructor.new(:scope => ((@scope)), :children => []) )
    @resource.stubs(:qualified_type).returns("Resource")
  end

  it "should evaluate all its parameters" do
    param = stub 'param'
    param.expects(:denotation).returns Puppet::Parser::Resource::Param.new(:name => "myparam", :value => "myvalue", :source => stub("source"))
    @resource.stubs(:parameters).returns [param]

    @resource.compute_denotation
  end

  it "should evaluate its title" do
    @resource.compute_denotation[0].title.should == "mytitle"
  end

  it "should flatten the titles array" do
    titles = []
    %w{one two}.each do |title|
      titles << Puppet::Parser::Expression::String.new(:scope => ((@scope)), :value => title)
    end

    array = Puppet::Parser::Expression::ArrayConstructor.new(:scope => ((@scope)), :children => titles)

    @resource.title = array
    result = @resource.compute_denotation.collect { |r| r.title }
    result.should be_include("one")
    result.should be_include("two")
  end

  it "should create and return one resource objects per title" do
    titles = []
    %w{one two}.each do |title|
      titles << Puppet::Parser::Expression::String.new(:scope => ((@scope)), :value => title)
    end

    array = Puppet::Parser::Expression::ArrayConstructor.new(:scope => ((@scope)), :children => titles)

    @resource.title = array
    result = @resource.compute_denotation.collect { |r| r.title }
    result.should be_include("one")
    result.should be_include("two")
  end

  it "should handover resources to the compiler" do
    titles = []
    %w{one two}.each do |title|
      titles << Puppet::Parser::Expression::String.new(:scope => ((@scope)), :value => title)
    end

    array = Puppet::Parser::Expression::ArrayConstructor.new(:scope => ((@scope)), :children => titles)

    @resource.title = array
    result = @resource.compute_denotation

    result.each do |res|
      @compiler.catalog.resource(res.ref).should be_instance_of(Puppet::Parser::Resource)
    end
  end
  it "should generate virtual resources if it is virtual" do
    @resource.virtual = true

    result = @resource.compute_denotation
    result[0].should be_virtual
  end

  it "should generate virtual and exported resources if it is exported" do
    @resource.exported = true

    result = @resource.compute_denotation
    result[0].should be_virtual
    result[0].should be_exported
  end

  # Related to #806, make sure resources always look up the full path to the resource.
  describe "when generating qualified resources" do
    before do
      @scope = Puppet::Parser::Scope.new :compiler => Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
      @parser = Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
      @parser.newdefine "one"
      @parser.newdefine "one::two"
      @parser.newdefine "three"
      @twoscope = @scope.newscope(:namespace => "one")
      @twoscope.resource = @scope.resource
    end

    def resource(type, params = nil)
      params ||= Puppet::Parser::Expression::ArrayConstructor.new(:scope => ((@scope)), :children => [])
      Puppet::Parser::Expression::Resource.new(:scope => ((@scope)), :type => type, :title => Puppet::Parser::Expression::String.new(:scope => ((@scope)), :value => "myresource"), :parameters => params)
    end

    it "should be able to generate resources with fully qualified type information" do
      resource("two").compute_denotation[0].type.should == "One::Two"
    end

    it "should be able to generate resources with unqualified type information" do
      resource("one").compute_denotation[0].type.should == "One"
    end

    it "should correctly generate resources that can look up builtin types" do
      resource("file").compute_denotation[0].type.should == "File"
    end

    it "should fail for resource types that do not exist" do
      lambda { resource("nosuchtype").compute_denotation }.should raise_error(Puppet::ParseError)
    end
  end
end
