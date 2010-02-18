#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/filebucket/file'

describe Puppet::Indirector::Filebucket::File do
    it "should be a subclass of the File terminus class" do
        Puppet::Indirector::Filebucket::File.superclass.should equal(Puppet::Indirector::Code)
    end

    it "should have documentation" do
        Puppet::Indirector::Filebucket::File.doc.should be_instance_of(String)
    end
end

describe Puppet::Indirector::Filebucket::File, " when initializing" do
    it "should use the filebucket settings section" do
        Puppet.settings.expects(:use).with(:filebucket)
        Puppet::Indirector::Filebucket::File.new
    end
end


describe Puppet::Indirector::Filebucket::File do
    before :each do
        Puppet.settings.stubs(:use)
        @store = Puppet::Indirector::Filebucket::File.new

        @digest = "70924d6fa4b2d745185fa4660703a5c0"
        @sum = stub 'sum', :name => @digest

        @dir = "/what/ever"

        Puppet.stubs(:[]).with(:bucketdir).returns(@dir)

        @path = Puppet::Filebucket.path_for(@digest, "contents")

        @request = stub 'request', :key => "md5/#{@digest}"
    end


    describe Puppet::Indirector::Filebucket::File, " when retrieving files" do
        # The smallest test that will use the calculated path
        it "should look for the calculated path" do
            ::File.expects(:exist?).with(@path).returns(false)
            @store.find(@request)
        end

        it "should return an instance of Puppet::Filebucket created with the content if the file exists" do
            content = "my content"
            bucketfile = stub 'bucketfile'
            
            Puppet::Filebucket.expects(:new).with(content, {:hash => "md5:#{@digest}"}).returns(bucketfile)

            ::File.expects(:exist?).with(@path).returns(true)
            ::File.expects(:read).with(@path).returns(content)

            @store.find(@request).should equal(bucketfile)
        end

        it "should return nil if no file is found" do
            ::File.expects(:exist?).with(@path).returns(false)
            @store.find(@request).should be_nil
        end

        it "should fail intelligently if a found file cannot be read" do
            ::File.expects(:exist?).with(@path).returns(true)
            ::File.expects(:read).with(@path).raises(RuntimeError)
            proc { @store.find(@request) }.should raise_error(Puppet::Error)
        end
    end
end
