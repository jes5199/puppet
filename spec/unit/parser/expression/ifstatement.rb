#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::IfStatement do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating" do

    before :each do
      @test = stub 'test'
      @test.stubs(:denotation).with(@scope)

      @stmt = stub 'stmt'
      @stmt.stubs(:denotation).with(@scope)

      @else = stub 'else'
      @else.stubs(:denotation).with(@scope)

      @ifstmt = Puppet::Parser::Expression::IfStatement.new :test => @test, :statements => @stmt
      @ifelsestmt = Puppet::Parser::Expression::IfStatement.new :test => @test, :statements => @stmt, :else => @else
    end

    it "should evaluate test" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @test.expects(:denotation).with(@scope)

      @ifstmt.compute_denotation(@scope)
    end

    it "should evaluate if statements if test is true" do
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @stmt.expects(:denotation).with(@scope)

      @ifstmt.compute_denotation(@scope)
    end

    it "should not evaluate if statements if test is false" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @stmt.expects(:denotation).with(@scope).never

      @ifstmt.compute_denotation(@scope)
    end

    it "should evaluate the else branch if test is false" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @else.expects(:denotation).with(@scope)

      @ifelsestmt.compute_denotation(@scope)
    end

    it "should not evaluate the else branch if test is true" do
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @else.expects(:denotation).with(@scope).never

      @ifelsestmt.compute_denotation(@scope)
    end

    it "should reset ephemeral statements after evaluation" do
      @scope.expects(:ephemeral_level).returns(:level)
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @stmt.expects(:denotation).with(@scope)
      @scope.expects(:unset_ephemeral_var).with(:level)

      @ifstmt.compute_denotation(@scope)
    end
  end
end
