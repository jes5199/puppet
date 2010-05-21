#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::Selector do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating" do

    before :each do
      @param = stub 'param'
      @param.stubs(:denotation).with(@scope).returns("value")

      @value1 = stub 'value1'
      @param1 = stub_everything 'param1'
      @param1.stubs(:denotation).with(@scope).returns(@param1)
      @param1.stubs(:respond_to?).with(:downcase).returns(false)
      @value1.stubs(:param).returns(@param1)
      @value1.stubs(:value).returns(@value1)

      @value2 = stub 'value2'
      @param2 = stub_everything 'param2'
      @param2.stubs(:denotation).with(@scope).returns(@param2)
      @param2.stubs(:respond_to?).with(:downcase).returns(false)
      @value2.stubs(:param).returns(@param2)
      @value2.stubs(:value).returns(@value2)

      @values = stub 'values', :instance_of? => true
      @values.stubs(:each).multiple_yields(@value1, @value2)

      @selector = Puppet::Parser::Expression::Selector.new :param => @param, :values => @values
      @selector.stubs(:fail)
    end

    it "should evaluate param" do
      @param.expects(:denotation).with(@scope)

      @selector.compute_denotation(@scope)
    end

    it "should scan each option" do
      @values.expects(:each).multiple_yields(@value1, @value2)

      @selector.compute_denotation(@scope)
    end

    describe "when scanning values" do
      it "should evaluate first matching option" do
        @param2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @value2.expects(:denotation).with(@scope)

        @selector.compute_denotation(@scope)
      end

      it "should return the first matching evaluated option" do
        @param2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @value2.stubs(:denotation).with(@scope).returns(:result)

        @selector.compute_denotation(@scope).should == :result
      end

      it "should evaluate the default option if none matched" do
        @param1.stubs(:is_a?).with(Puppet::Parser::Expression::Default).returns(true)
        @value1.expects(:denotation).with(@scope).returns(@param1)

        @selector.compute_denotation(@scope)
      end

      it "should return the default evaluated option if none matched" do
        result = stub 'result'
        @param1.stubs(:is_a?).with(Puppet::Parser::Expression::Default).returns(true)
        @value1.stubs(:denotation).returns(result)

        @selector.compute_denotation(@scope).should == result
      end

      it "should return nil if nothing matched" do
        @selector.compute_denotation(@scope).should be_nil
      end

      it "should delegate matching to evaluate_match" do
        @param1.expects(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }

        @selector.compute_denotation(@scope)
      end

      it "should evaluate the matching param" do
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)

        @value1.expects(:denotation).with(@scope)

        @selector.compute_denotation(@scope)
      end

      it "should return this evaluated option if it matches" do
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @value1.stubs(:denotation).with(@scope).returns(:result)

        @selector.compute_denotation(@scope).should == :result
      end

      it "should unset scope ephemeral variables after option evaluation" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @value1.stubs(:denotation).with(@scope).returns(:result)

        @scope.expects(:unset_ephemeral_var).with(:level)

        @selector.compute_denotation(@scope)
      end

      it "should not leak ephemeral variables even if evaluation fails" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @value1.stubs(:denotation).with(@scope).raises

        @scope.expects(:unset_ephemeral_var).with(:level)

        lambda { @selector.compute_denotation(@scope) }.should raise_error
      end

      it "should fail if there is no default" do
        @selector.expects(:fail)

        @selector.compute_denotation(@scope)
      end
    end
  end
  describe "when converting to string" do
    it "should produce a string version of this selector" do
      values = Puppet::Parser::Expression::ArrayConstructor.new :children => [ Puppet::Parser::Expression::ResourceParam.new(:param => "type", :value => "value", :add => false) ]
      param = Puppet::Parser::Expression::Variable.new :value => "myvar"
      selector = Puppet::Parser::Expression::Selector.new :param => param, :values => values
      selector.to_s.should == "$myvar ? { type => value }"
    end
  end
end
