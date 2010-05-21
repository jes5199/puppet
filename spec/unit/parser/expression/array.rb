#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::ArrayConstructor do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should have a [] accessor" do
    array = Puppet::Parser::Expression::ArrayConstructor.new :children => []
    array.should respond_to(:[])
  end

  it "should evaluate all its children" do
    item1 = stub "item1", :is_a? => true
    item2 = stub "item2", :is_a? => true

    item1.expects(:denotation).with(@scope).returns(123)
    item2.expects(:denotation).with(@scope).returns(246)

    operator = Puppet::Parser::Expression::ArrayConstructor.new :children => [item1,item2]
    operator.compute_denotation(@scope)
  end

  it "should evaluate childrens of type ArrayConstructor" do
    item1 = stub "item1", :is_a? => true
    item2 = stub "item2"
    item2.stubs(:is_a?).with(Puppet::Parser::Expression).returns(true)
    item2.stubs(:instance_of?).with(Puppet::Parser::Expression::ArrayConstructor).returns(true)
    item2.stubs(:each).yields(item1)

    item1.expects(:denotation).with(@scope).returns(123)

    operator = Puppet::Parser::Expression::ArrayConstructor.new :children => [item2]
    operator.compute_denotation(@scope).should == [123]
  end

  it "should flatten children coming from children ArrayConstructor" do
    item1 = stub "item1", :is_a? => true
    item2 = stub "item2"
    item2.stubs(:is_a?).with(Puppet::Parser::Expression).returns(true)
    item2.stubs(:instance_of?).with(Puppet::Parser::Expression::ArrayConstructor).returns(true)
    item2.stubs(:each).yields([item1])

    item1.expects(:denotation).with(@scope).returns(123)

    operator = Puppet::Parser::Expression::ArrayConstructor.new :children => [item2]
    operator.compute_denotation(@scope).should == [123]
  end

  it "should not flatten the results of children evaluation" do
    item1 = stub "item1", :is_a? => true
    item2 = stub "item2"
    item2.stubs(:is_a?).with(Puppet::Parser::Expression).returns(true)
    item2.stubs(:instance_of?).with(Puppet::Parser::Expression::ArrayConstructor).returns(true)
    item2.stubs(:each).yields([item1])

    item1.expects(:denotation).with(@scope).returns([123])

    operator = Puppet::Parser::Expression::ArrayConstructor.new :children => [item2]
    operator.compute_denotation(@scope).should == [[123]]
  end

  it "should return a valid string with to_s" do
    a = stub 'a', :is_a? => true, :to_s => "a"
    b = stub 'b', :is_a? => true, :to_s => "b"
    array = Puppet::Parser::Expression::ArrayConstructor.new :children => [a,b]

    array.to_s.should == "[a, b]"
  end
end
