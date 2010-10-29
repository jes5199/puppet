#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/route'

describe "a route" do
  describe "when created" do
    it "should take a model and a terminus" do
      route = Puppet::Indirector::Route.new( :facts, :yaml )
      route.terminus_class.should == Puppet::Node::Facts::Yaml
    end
  end  

  # REST methods
  it "should have a find method" do
    route = Puppet::Indirector::Route.new( :facts, :yaml )
  
    Puppet::Node::Facts::Yaml.any_instance.expects(:find).with do |request|
      request.is_a? Puppet::Indirector::Request and request.key == "key"
    end

    route.find( "key" )
  end

  it "should have a save method" do
    route = Puppet::Indirector::Route.new( :facts, :yaml )

    facts = Puppet::Node::Facts.new( "nodename", :fact => :value )

    Puppet::Node::Facts::Yaml.any_instance.expects(:save).with do |request|
      request.is_a? Puppet::Indirector::Request and request.key == "key" and request.instance == facts
    end
  
    route.save( "key", facts )
  end

  it "should have a search method" do
    route = Puppet::Indirector::Route.new( :inventory, :yaml )
  
    Puppet::Node::Inventory::Yaml.any_instance.expects(:search).with do |request|
      request.is_a? Puppet::Indirector::Request and request.key == "key" and request.options[:filter] == "value"
    end

    route.search( "key", :filter => "value" )
  end

  it "should have a destroy method" do
    route = Puppet::Indirector::Route.new( :facts, :yaml )
  
    Puppet::Node::Facts::Yaml.any_instance.expects(:destroy).with do |request|
      request.is_a? Puppet::Indirector::Request and request.key == "key"
    end

    route.destroy( "key" )
  end
end
