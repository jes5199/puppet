#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/network/client/dipper'
describe Puppet::Network::Client::Dipper do
    it "should fail in an informative way when there are failures backing up to the server" do
        File.stubs(:exists?).returns true
        File.stubs(:read).returns "content"

        @dipper = Puppet::Network::Client::Dipper.new(:Path => "/my/bucket")

        filemock = stub "bucketfile"
        Puppet::FileBucket::File.stubs(:new).returns(filemock)
        filemock.expects(:name).returns "name"
        filemock.expects(:save).raises ArgumentError

        lambda { @dipper.backup("/my/file") }.should raise_error(Puppet::Error)
    end
end
