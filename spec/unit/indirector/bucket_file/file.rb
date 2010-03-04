#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_bucket_file/file'

describe Puppet::FileBucketFile::File do
    it "should be a subclass of the File terminus class" do
        Puppet::FileBucketFile::File.superclass.should equal(Puppet::Indirector::Code)
    end

    it "should have documentation" do
        Puppet::FileBucketFile::File.doc.should be_instance_of(String)
    end

    describe "when initializing" do
        it "should use the filebucket settings section" do
            Puppet.settings.expects(:use).with(:filebucket)
            Puppet::FileBucketFile::File.new
        end
    end

    describe "when retrieving files" do
        before :each do
            Puppet.settings.stubs(:use)
            @store = Puppet::FileBucketFile::File.new

            @digest = "70924d6fa4b2d745185fa4660703a5c0"
            @sum = stub 'sum', :name => @digest

            @dir = "/what/ever"

            Puppet.stubs(:[]).with(:bucketdir).returns(@dir)

            @contents_path = '/what/ever/7/0/9/2/4/d/6/f/70924d6fa4b2d745185fa4660703a5c0/contents'
            @paths_path    = '/what/ever/7/0/9/2/4/d/6/f/70924d6fa4b2d745185fa4660703a5c0/paths'

            @request = stub 'request', :key => "md5/#{@digest}/remote/path"
        end

        it "should call find_by_checksum" do
            @store.expects(:find_by_checksum).with("md5:#{@digest}").returns(false)
            @store.find(@request)
        end

        it "should look for the calculated path" do
            ::File.expects(:exists?).with(@contents_path).returns(false)
            @store.find(@request)
        end

        it "should return an instance of Puppet::FileBucket::File created with the content if the file exists" do
            content = "my content"
            bucketfile = stub 'bucketfile'
            bucketfile.stubs(:bucket_path)
            bucketfile.stubs(:checksum_data).returns(@digest)

            bucketfile.expects(:contents=).with(content)
            Puppet::FileBucket::File.expects(:new).with(nil, {:checksum => "md5:#{@digest}"}).returns(bucketfile)

            ::File.expects(:exists?).with(@contents_path).returns(true)
            ::File.expects(:exists?).with(@paths_path).returns(false)
            ::File.expects(:read).with(@contents_path).returns(content)

            @store.find(@request).should equal(bucketfile)
        end

        it "should return nil if no file is found" do
            ::File.expects(:exists?).with(@contents_path).returns(false)
            @store.find(@request).should be_nil
        end

        it "should fail intelligently if a found file cannot be read" do
            ::File.expects(:exists?).with(@contents_path).returns(true)
            ::File.expects(:read).with(@contents_path).raises(RuntimeError)
            proc { @store.find(@request) }.should raise_error(Puppet::Error)
        end

    end
end
