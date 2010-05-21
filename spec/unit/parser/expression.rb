#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/expression'

describe Puppet::Parser::Expression do

  it "should use the file lookup module" do
    Puppet::Parser::Expression.ancestors.should be_include(Puppet::FileCollection::Lookup)
  end

  it "should have a doc accessor" do
    ast = Puppet::Parser::Expression.new({})
    ast.should respond_to(:doc)
  end

  it "should have a use_docs accessor to indicate it wants documentation" do
    ast = Puppet::Parser::Expression.new({})
    ast.should respond_to(:use_docs)
  end

  [ Puppet::Parser::Expression::Collection, Puppet::Parser::Expression::Else,
    Puppet::Parser::Expression::Function, Puppet::Parser::Expression::IfStatement,
    Puppet::Parser::Expression::Resource, Puppet::Parser::Expression::ResourceDefaults,
    Puppet::Parser::Expression::ResourceOverride, Puppet::Parser::Expression::VarDef
  ].each do |k|
    it "#{k}.use_docs should return true" do
      ast = k.new({})
      ast.use_docs.should be_true
    end
  end

  describe "when initializing" do
    it "should store the doc argument if passed" do
      ast = Puppet::Parser::Expression.new(:doc => "documentation")
      ast.doc.should == "documentation"
    end
  end

end
