#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::HashConstructor do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should have a merge functionality" do
    hash = Puppet::Parser::Expression::HashConstructor.new(:value => {})
    hash.should respond_to(:merge)
  end

  it "should be able to merge 2 Expression hashes" do
    hash = Puppet::Parser::Expression::HashConstructor.new(:value => { "a" => "b" })

    hash.merge(Puppet::Parser::Expression::HashConstructor.new(:value => {"c" => "d"}))

    hash.value.should == { "a" => "b", "c" => "d" }
  end

  it "should be able to merge with a ruby Hash" do
    hash = Puppet::Parser::Expression::HashConstructor.new(:value => { "a" => "b" })

    hash.merge({"c" => "d"})

    hash.value.should == { "a" => "b", "c" => "d" }
  end

  it "should evaluate each hash value" do
    key1 = stub "key1"
    value1 = stub "value1"
    key2 = stub "key2"
    value2 = stub "value2"

    value1.expects(:denotation).with(@scope).returns("b")
    value2.expects(:denotation).with(@scope).returns("d")

    operator = Puppet::Parser::Expression::HashConstructor.new(:value => { key1 => value1, key2 => value2})
    operator.compute_denotation(@scope)
  end

  it "should evaluate the hash keys if they are Expression instances" do
    key1 = stub "key1"
    value1 = stub "value1", :denotation => "one"
    key2 = stub "key2"
    value2 = stub "value2", :denotation => "two"

    key1.expects(:denotation).with(@scope).returns("1")
    key2.expects(:denotation).with(@scope).returns("2")

    operator = Puppet::Parser::Expression::HashConstructor.new(:value => { key1 => value1, key2 => value2})
    hash = operator.compute_denotation(@scope)
    hash["1"].should == "one"
    hash["2"].should == "two"
  end

  it "should evaluate the hash keys if they are not Expression instances" do
    key1 = "1"
    value1 = stub "value1", :denotation => "one"
    key2 = "2"
    value2 = stub "value2", :denotation => "two"

    operator = Puppet::Parser::Expression::HashConstructor.new(:value => { key1 => value1, key2 => value2})
    hash = operator.compute_denotation(@scope)
    hash["1"].should == "one"
    hash["2"].should == "two"
  end

  it "should return an evaluated hash" do
    key1 = stub "key1"
    value1 = stub "value1", :denotation => "b"
    key2 = stub "key2"
    value2 = stub "value2", :denotation => "d"

    operator = Puppet::Parser::Expression::HashConstructor.new(:value => { key1 => value1, key2 => value2})
    operator.compute_denotation(@scope).should == { key1 => "b", key2 => "d" }
  end

  it "should return a valid string with to_s" do
    hash = Puppet::Parser::Expression::HashConstructor.new(:value => { "a" => "b", "c" => "d" })

    hash.to_s.should == '{a => b, c => d}'
  end
end
