#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::VarDef do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating" do

    it "should evaluate arguments" do
      name = mock 'name'
      value = mock 'value'

      name.expects(:denotation).with(@scope)
      value.expects(:denotation).with(@scope)

      vardef = Puppet::Parser::Expression::VarDef.new :name => name, :value => value, :file => nil,
        :line => nil
      vardef.compute_denotation(@scope)
    end

    it "should be in append=false mode if called without append" do
      name = stub 'name', :denotation => "var"
      value = stub 'value', :denotation => "1"

      @scope.expects(:setvar).with { |name,value,options| options[:append] == nil }

      vardef = Puppet::Parser::Expression::VarDef.new :name => name, :value => value, :file => nil,
        :line => nil
      vardef.compute_denotation(@scope)
    end

    it "should call scope in append mode if append is true" do
      name = stub 'name', :denotation => "var"
      value = stub 'value', :denotation => "1"

      @scope.expects(:setvar).with { |name,value,options| options[:append] == true }

      vardef = Puppet::Parser::Expression::VarDef.new :name => name, :value => value, :file => nil,
        :line => nil, :append => true
      vardef.compute_denotation(@scope)
    end

    describe "when dealing with hash" do
      it "should delegate to the HashOrArrayAccess assign" do
        access = stub 'name'
        access.stubs(:is_a?).with(Puppet::Parser::Expression::HashOrArrayAccess).returns(true)
        value = stub 'value', :denotation => "1"
        vardef = Puppet::Parser::Expression::VarDef.new :name => access, :value => value, :file => nil, :line => nil

        access.expects(:assign).with(@scope, '1')

        vardef.compute_denotation(@scope)
      end
    end

  end
end
