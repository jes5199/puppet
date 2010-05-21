#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::IfStatement do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating" do

    before :each do
      @test = stub 'test'
      @test.stubs(:denotation)

      @stmt = stub 'stmt'
      @stmt.stubs(:denotation)

      @else = stub 'else'
      @else.stubs(:denotation)

      @ifstmt = Puppet::Parser::Expression::IfStatement.new :scope => ((@scope)), :test => @test, :statements => @stmt
      @ifelsestmt = Puppet::Parser::Expression::IfStatement.new :scope => ((@scope)), :test => @test, :statements => @stmt, :else => @else
    end

    it "should evaluate test" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @test.expects(:denotation)

      @ifstmt.compute_denotation
    end

    it "should evaluate if statements if test is true" do
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @stmt.expects(:denotation)

      @ifstmt.compute_denotation
    end

    it "should not evaluate if statements if test is false" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @stmt.expects(:denotation).never

      @ifstmt.compute_denotation
    end

    it "should evaluate the else branch if test is false" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @else.expects(:denotation)

      @ifelsestmt.compute_denotation
    end

    it "should not evaluate the else branch if test is true" do
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @else.expects(:denotation).never

      @ifelsestmt.compute_denotation
    end

    it "should reset ephemeral statements after evaluation" do
      @scope.expects(:ephemeral_level).returns(:level)
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @stmt.expects(:denotation)
      @scope.expects(:unset_ephemeral_var).with(:level)

      @ifstmt.compute_denotation
    end
  end
end
