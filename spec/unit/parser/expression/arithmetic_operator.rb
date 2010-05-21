#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::ArithmeticOperator do

  ast = Puppet::Parser::Expression

  before :each do
    @scope = Puppet::Parser::Scope.new
    @one = stub 'lval', :denotation => 1
    @two = stub 'rval', :denotation => 2
  end

  it "should evaluate both branches" do
    lval = stub "lval"
    lval.expects(:denotation).returns(1)
    rval = stub "rval"
    rval.expects(:denotation).returns(2)

    operator = Puppet::Parser::Expression::ArithmeticOperator.new :scope => ((@scope)), :rval => rval, :operator => "+", :lval => lval
    operator.compute_denotation
  end

  it "should fail for an unknown operator" do
    lambda { operator = Puppet::Parser::Expression::ArithmeticOperator.new :scope => ((@scope)), :lval => @one, :operator => "%", :rval => @two }.should raise_error
  end

  it "should call Puppet::Parser::Scope.number?" do
    Puppet::Parser::Scope.expects(:number?).with(1).returns(1)
    Puppet::Parser::Scope.expects(:number?).with(2).returns(2)

    Puppet::Parser::Expression::ArithmeticOperator.new(:scope => ((@scope)), :lval => @one, :operator => "+", :rval => @two).compute_denotation
  end


  %w{ + - * / << >>}.each do |op|
    it "should call ruby Numeric '#{op}'" do
      one = stub 'one'
      two = stub 'two'
      operator = Puppet::Parser::Expression::ArithmeticOperator.new :scope => ((@scope)), :lval => @one, :operator => op, :rval => @two
      Puppet::Parser::Scope.stubs(:number?).with(1).returns(one)
      Puppet::Parser::Scope.stubs(:number?).with(2).returns(two)
      one.expects(:send).with(op,two)
      operator.compute_denotation
    end
  end

  it "should work even with numbers embedded in strings" do
    two = stub 'two', :denotation => "2"
    one = stub 'one', :denotation => "1"
    operator = Puppet::Parser::Expression::ArithmeticOperator.new :scope => ((@scope)), :lval => two, :operator => "+", :rval => one
    operator.compute_denotation.should == 3
  end

  it "should work even with floats" do
    two = stub 'two', :denotation => 2.53
    one = stub 'one', :denotation => 1.80
    operator = Puppet::Parser::Expression::ArithmeticOperator.new :scope => ((@scope)), :lval => two, :operator => "+", :rval => one
    operator.compute_denotation.should == 4.33
  end

  it "should work for variables too" do
    @scope.expects(:lookupvar).with("one", false).returns(1)
    @scope.expects(:lookupvar).with("two", false).returns(2)
    one = ast::Variable.new( :value => "one" )
    two = ast::Variable.new( :value => "two" )

    operator = Puppet::Parser::Expression::ArithmeticOperator.new :scope => ((@scope)), :lval => one, :operator => "+", :rval => two
    operator.compute_denotation.should == 3
  end

end
