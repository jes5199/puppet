#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::ResourceDefaults do

  ast = Puppet::Parser::Expression

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new(:compiler => @compiler)
    @params = Puppet::Parser::Expression::ArrayConstructor.new({})
    @compiler.stubs(:add_override)
  end

  it "should add defaults when evaluated" do
    default = Puppet::Parser::Expression::ResourceDefaults.new :type => "file", :parameters => Puppet::Parser::Expression::ArrayConstructor.new(:children => [])
    default.compute_denotation @scope

    @scope.lookupdefaults("file").should_not be_nil
  end
end
