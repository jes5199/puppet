#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/runner/local'

describe Puppet::Agent::Runner::Local do
    it "should be a sublcass of Puppet::Indirector::Code" do
        Puppet::Agent::Runner::Local.superclass.should equal(Puppet::Indirector::Code)
    end

    it "should call runner.run on save and return the runner" do
        runner  = Puppet::Agent::Runner.new
        runner.stubs(:run).returns(runner)

        request = Puppet::Indirector::Request.new(:indirection, :save, "anything")
        request.instance = runner = Puppet::Agent::Runner.new
        Puppet::Agent::Runner::Local.new.save(request).should == runner
    end
end
