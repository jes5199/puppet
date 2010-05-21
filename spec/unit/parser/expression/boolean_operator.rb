#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::BooleanOperator do

  ast = Puppet::Parser::Expression

  before :each do
    @scope = Puppet::Parser::Scope.new
    @true_ast = ast::Boolean.new( :value => true)
    @false_ast = ast::Boolean.new( :value => false)
  end

  it "should evaluate left operand inconditionally" do
    lval = stub "lval"
    lval.expects(:denotation).with(@scope).returns("true")
    rval = stub "rval", :denotation => false
    rval.expects(:denotation).never

    operator = ast::BooleanOperator.new :rval => rval, :operator => "or", :lval => lval
    operator.compute_denotation(@scope)
  end

  it "should evaluate right 'and' operand only if left operand is true" do
    lval = stub "lval", :denotation => true
    rval = stub "rval", :denotation => false
    rval.expects(:denotation).with(@scope).returns(false)
    operator = ast::BooleanOperator.new :rval => rval, :operator => "and", :lval => lval
    operator.compute_denotation(@scope)
  end

  it "should evaluate right 'or' operand only if left operand is false" do
    lval = stub "lval", :denotation => false
    rval = stub "rval", :denotation => false
    rval.expects(:denotation).with(@scope).returns(false)
    operator = ast::BooleanOperator.new :rval => rval, :operator => "or", :lval => lval
    operator.compute_denotation(@scope)
  end

  it "should return true for false OR true" do
    ast::BooleanOperator.new(:rval => @true_ast, :operator => "or", :lval => @false_ast).compute_denotation(@scope).should be_true
  end

  it "should return false for true AND false" do
    ast::BooleanOperator.new(:rval => @true_ast, :operator => "and", :lval => @false_ast ).compute_denotation(@scope).should be_false
  end

  it "should return true for true AND true" do
    ast::BooleanOperator.new(:rval => @true_ast, :operator => "and", :lval => @true_ast ).compute_denotation(@scope).should be_true
  end

end
