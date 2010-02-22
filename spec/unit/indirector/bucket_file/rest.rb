#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/indirector/bucket_file/rest'

describe Puppet::Indirector::BucketFile::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Indirector::BucketFile::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
