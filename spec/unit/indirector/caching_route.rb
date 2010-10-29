#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/caching_route'

describe "a caching route" do
  before do
    @main_route  = Puppet::Indirector::Route.new( :facts, :yaml   )
    @cache_route = Puppet::Indirector::Route.new( :facts, :memory )
    @route = Puppet::Indirector::CachingRoute.new( 
        @main_route,
        @cache_route,
        :ttl => 1800
    )
  end

  describe "when created" do
    it "should take a model, a terminus, and a cache terminus" do
      @route.terminus_class.should == Puppet::Node::Facts::Yaml
      @route.cache_terminus_class.should == Puppet::Node::Facts::Memory
    end
  end

  describe "when finding" do 
    it "should look in the cache, and save found results to the cache, with an expiration" do
      facts = Puppet::Node::Facts.new( "nodename", :fact => :value )
      @now = Time.now
      Time.expects(:now).returns(@now)

      Puppet::Node::Facts::Memory.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns(nil)
    
      Puppet::Node::Facts::Yaml.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns(facts)

      Puppet::Node::Facts::Memory.any_instance.expects(:save).with do |request|
        request.is_a? Puppet::Indirector::Request and request.instance == facts and request.key == "key"
      end

      @route.find( "key" ).should == facts

      facts.expiration.should == @now + Puppet[:runinterval].to_i
    end

    it "should look in the cache, and return what it finds" do
      facts = Puppet::Node::Facts.new( "nodename", :fact => :value )

      Puppet::Node::Facts::Memory.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns(facts)
    
      Puppet::Node::Facts::Yaml.any_instance.expects(:find).never

      Puppet::Node::Facts::Memory.any_instance.expects(:save).never

      @route.find( "key" ).should == facts
    end

    it "should look in the cache, discard expired results, and save new found results to the cache, with an expiration" do
      old_facts = Puppet::Node::Facts.new( "nodename", :fact => :old_value )
      old_facts.expiration = Time.now - 60

      facts = Puppet::Node::Facts.new( "nodename", :fact => :value )
      @now = Time.now
      Time.expects(:now).returns(@now).at_least_once

      Puppet::Node::Facts::Memory.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns(old_facts)
    
      Puppet::Node::Facts::Yaml.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns(facts)

      Puppet::Node::Facts::Memory.any_instance.expects(:save).with do |request|
        request.is_a? Puppet::Indirector::Request and request.instance == facts and request.key == "key"
      end

      @route.find( "key" ).should == facts

      facts.expiration.should == @now + Puppet[:runinterval].to_i
    end

    it "should not cache absent results" do
      Puppet::Node::Facts::Memory.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns nil
    
      Puppet::Node::Facts::Yaml.any_instance.expects(:find).with do |request|
        request.is_a? Puppet::Indirector::Request and request.key == "key"
      end.returns nil

      Puppet::Node::Facts::Memory.any_instance.expects(:save).never

      @route.find( "key" ).should == nil
    end

  end
end
