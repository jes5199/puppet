#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/node/ldap'

describe Puppet::Node::Ldap do
  it "should use a restrictive filter when searching for nodes in a class" do
    ldap = Puppet::Node.indirection.terminus(:ldap)
    Puppet::Node.terminus_class = :ldap
    ldap.class.any_instance.expects(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=foo))")

    Puppet::Node.search "eh", :class => "foo"
  end

  after do
    Puppet::Node.terminus_class = nil
  end
end
