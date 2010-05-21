#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::Minus do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should evaluate its argument" do
    value = stub "value"
    value.expects(:denotation).with(@scope).returns(123)

    operator = Puppet::Parser::Expression::Minus.new :value => value
    operator.compute_denotation(@scope)
  end

  it "should fail if argument is not a string or integer" do
    array_ast = stub 'array_ast', :denotation => [2]
    operator = Puppet::Parser::Expression::Minus.new :value => array_ast
    lambda { operator.compute_denotation(@scope) }.should raise_error
  end

  it "should work with integer as string" do
    string = stub 'string', :denotation => "123"
    operator = Puppet::Parser::Expression::Minus.new :value => string
    operator.compute_denotation(@scope).should == -123
  end

  it "should work with integers" do
    int = stub 'int', :denotation => 123
    operator = Puppet::Parser::Expression::Minus.new :value => int
    operator.compute_denotation(@scope).should == -123
  end

end
