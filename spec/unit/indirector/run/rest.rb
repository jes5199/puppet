#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/run/rest'

describe Puppet::Agent::Run::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Agent::Run::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
