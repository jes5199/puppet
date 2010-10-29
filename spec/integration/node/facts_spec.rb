#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-4-8.
#  Copyright (c) 2008. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Node::Facts do
  describe "when using the indirector" do
    after { Puppet::Util::Cacher.expire }

    it "should be able to delegate to the :yaml terminus" do
      Puppet::Node::Facts.terminus_class = :yaml

      # Load now, before we stub the exists? method.
      terminus = Puppet::Node::Facts.indirection.terminus(:yaml)

      terminus.class.any_instance.expects(:path).with("me").returns "/my/yaml/file"
      FileTest.expects(:exist?).with("/my/yaml/file").returns false

      Puppet::Node::Facts.find("me").should be_nil
    end

    it "should be able to delegate to the :facter terminus" do
      Puppet::Node::Facts.terminus_class = :facter

      Facter.expects(:to_hash).returns "facter_hash"
      facts = Puppet::Node::Facts.new("me")
      Puppet::Node::Facts.expects(:new).with("me", "facter_hash").returns facts

      Puppet::Node::Facts.find("me").should equal(facts)
    end
  end
end
