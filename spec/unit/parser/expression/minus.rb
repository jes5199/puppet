#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::Minus do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should evaluate its argument" do
    value = stub "value"
    value.expects(:denotation).returns(123)

    operator = Puppet::Parser::Expression::Minus.new :scope => ((@scope)), :value => value
    operator.compute_denotation
  end

  it "should fail if argument is not a string or integer" do
    array_ast = stub 'array_ast', :denotation => [2]
    operator = Puppet::Parser::Expression::Minus.new :scope => ((@scope)), :value => array_ast
    lambda { operator.compute_denotation }.should raise_error
  end

  it "should work with integer as string" do
    string = stub 'string', :denotation => "123"
    operator = Puppet::Parser::Expression::Minus.new :scope => ((@scope)), :value => string
    operator.compute_denotation.should == -123
  end

  it "should work with integers" do
    int = stub 'int', :denotation => 123
    operator = Puppet::Parser::Expression::Minus.new :scope => ((@scope)), :value => int
    operator.compute_denotation.should == -123
  end

end
