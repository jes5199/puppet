#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-4-8.
#  Copyright (c) 2008. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Resource::Catalog do
  describe "when pson is available" do
    confine "PSON library is missing" => Puppet.features.pson?
    it "should support pson" do
      Puppet::Resource::Catalog.supported_formats.should be_include(:pson)
    end
  end

  describe "when using the indirector" do
    after do
      Puppet::Util::Cacher.expire
      Puppet::Resource::Catalog.terminus_class = nil
    end

    before do
      # This is so the tests work w/out networking.
      Facter.stubs(:to_hash).returns({"hostname" => "foo.domain.com"})
      Facter.stubs(:value).returns("eh")
    end


    it "should be able to delegate to the :yaml terminus" do
      Puppet::Resource::Catalog.terminus_class = :yaml

      # Load now, before we stub the exists? method.
      terminus = Puppet::Resource::Catalog.indirection.terminus(:yaml)
      terminus.class.any_instance.expects(:path).with("me").returns "/my/yaml/file"

      FileTest.expects(:exist?).with("/my/yaml/file").returns false
      Puppet::Resource::Catalog.find("me").should be_nil
    end

    it "should be able to delegate to the :compiler terminus" do
      Puppet::Resource::Catalog.terminus_class = :compiler

      # Load now, before we stub the exists? method.
      compiler = Puppet::Resource::Catalog.indirection.terminus(:compiler)

      node = mock 'node'
      node.stub_everything

      Puppet::Node.expects(:find).returns(node)
      compiler.class.any_instance.expects(:compile).with(node).returns nil

      Puppet::Resource::Catalog.find("me").should be_nil
    end

    it "should pass provided node information directly to the terminus" do
      default_route = mock 'default_route'

      Puppet::Resource::Catalog.stubs(:default_route).returns default_route

      node = mock 'node'
      default_route.expects(:find).with { |key, options| options[:use_node] == node }
      Puppet::Resource::Catalog.find("me", :use_node => node)
    end
  end
end
