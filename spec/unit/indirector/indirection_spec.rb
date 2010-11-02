#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/indirection'

describe Puppet::Indirector::Indirection do
  describe "when initializing" do
    it "should store a reference to itself" do
      @indirection = Puppet::Indirector::Indirection.new(Object.new, :testingness)
      Puppet::Indirector::Indirection.instance(:testingness).should be_instance_of(Puppet::Indirector::Indirection)
      Puppet::Indirector::Indirection.instance(:testingness).delete
    end

    it "should keep a reference to the indirecting model" do
      model = mock 'model'
      @indirection = Puppet::Indirector::Indirection.new(model, :myind)
      @indirection.model.should equal(model)
    end

    it "should set the name" do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :myind)
      @indirection.name.should == :myind
    end

    it "should require indirections to have unique names" do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      proc { Puppet::Indirector::Indirection.new(:test) }.should raise_error(ArgumentError)
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when managing indirection instances" do
    it "should allow an indirection to be retrieved by name" do
      @indirection = Puppet::Indirector::Indirection.new(mock('model'), :test)
      Puppet::Indirector::Indirection.instance(:test).should equal(@indirection)
    end

    it "should return nil when the named indirection has not been created" do
      Puppet::Indirector::Indirection.instance(:test).should be_nil
    end

    it "should allow an indirection's model to be retrieved by name" do
      mock_model = mock('model')
      @indirection = Puppet::Indirector::Indirection.new(mock_model, :test)
      Puppet::Indirector::Indirection.model(:test).should equal(mock_model)
    end

    it "should return nil when no model matches the requested name" do
      Puppet::Indirector::Indirection.model(:test).should be_nil
    end

    after do
      @indirection.delete if defined?(@indirection)
    end
  end

  describe "when retrieving a terminus" do
    it "should memoize the terminus object by name" do
      indirection = Puppet::Node::Facts.indirection
      indirection.terminus(:yaml).should equal( indirection.terminus(:yaml) )
    end
  end

end
