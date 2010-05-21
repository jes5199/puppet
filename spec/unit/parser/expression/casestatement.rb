#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::CaseStatement do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating" do

    before :each do
      @test = stub 'test'
      @test.stubs(:denotation).with(@scope).returns("value")

      @option1 = stub 'option1', :eachopt => nil, :default? => false
      @option2 = stub 'option2', :eachopt => nil, :default? => false

      @options = stub 'options'
      @options.stubs(:each).multiple_yields(@option1, @option2)

      @casestmt = Puppet::Parser::Expression::CaseStatement.new :test => @test, :options => @options
    end

    it "should evaluate test" do
      @test.expects(:denotation).with(@scope)

      @casestmt.compute_denotation(@scope)
    end

    it "should scan each option" do
      @options.expects(:each).multiple_yields(@option1, @option2)

      @casestmt.compute_denotation(@scope)
    end

    describe "when scanning options" do
      before :each do
        @opval1 = stub_everything 'opval1'
        @option1.stubs(:eachopt).yields(@opval1)

        @opval2 = stub_everything 'opval2'
        @option2.stubs(:eachopt).yields(@opval2)
      end

      it "should evaluate each sub-option" do
        @option1.expects(:eachopt)
        @option2.expects(:eachopt)

        @casestmt.compute_denotation(@scope)
      end

      it "should evaluate first matching option" do
        @opval2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @option2.expects(:denotation).with(@scope)

        @casestmt.compute_denotation(@scope)
      end

      it "should return the first matching evaluated option" do
        @opval2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @option2.stubs(:denotation).with(@scope).returns(:result)

        @casestmt.compute_denotation(@scope).should == :result
      end

      it "should evaluate the default option if none matched" do
        @option1.stubs(:default?).returns(true)
        @option1.expects(:denotation).with(@scope)

        @casestmt.compute_denotation(@scope)
      end

      it "should return the default evaluated option if none matched" do
        @option1.stubs(:default?).returns(true)
        @option1.stubs(:denotation).with(@scope).returns(:result)

        @casestmt.compute_denotation(@scope).should == :result
      end

      it "should return nil if nothing matched" do
        @casestmt.compute_denotation(@scope).should be_nil
      end

      it "should match and set scope ephemeral variables" do
        @opval1.expects(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }

        @casestmt.compute_denotation(@scope)
      end

      it "should evaluate this regex option if it matches" do
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)

        @option1.expects(:denotation).with(@scope)

        @casestmt.compute_denotation(@scope)
      end

      it "should return this evaluated regex option if it matches" do
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @option1.stubs(:denotation).with(@scope).returns(:result)

        @casestmt.compute_denotation(@scope).should == :result
      end

      it "should unset scope ephemeral variables after option evaluation" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @option1.stubs(:denotation).with(@scope).returns(:result)

        @scope.expects(:unset_ephemeral_var).with(:level)

        @casestmt.compute_denotation(@scope)
      end

      it "should not leak ephemeral variables even if evaluation fails" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @option1.stubs(:denotation).with(@scope).raises

        @scope.expects(:unset_ephemeral_var).with(:level)

        lambda { @casestmt.compute_denotation(@scope) }.should raise_error
      end
    end

  end

  it "should match if any of the provided options evaluate as true" do
    ast = nil
    Expression = Puppet::Parser::Expression

    tests = {
      "one" => %w{a b c},
      "two" => %w{e f g}
    }
    options = tests.collect do |result, values|
      values = values.collect { |v| Expression::Leaf.new :value => v }

            Expression::CaseOpt.new(
        :value => Expression::ArrayConstructor.new(:children => values),
        
        :statements => Expression::Leaf.new(:value => result))
    end
    options << Expression::CaseOpt.new(:value => Expression::Default.new(:value => "default"), :statements => Expression::Leaf.new(:value => "default"))

    ast = nil
    param = Expression::Variable.new(:value => "testparam")
    ast = Expression::CaseStatement.new(:test => param, :options => options)

    tests.each do |should, values|
      values.each do |value|
        @scope = Puppet::Parser::Scope.new
        @scope.setvar("testparam", value)
        result = ast.compute_denotation(@scope)

        result.should == should
      end
    end
  end
end
