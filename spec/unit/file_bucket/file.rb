#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_bucket/file'
require 'digest/md5'
require 'digest/sha1'

describe Puppet::FileBucket::File do
    before do
        # this is the default from spec_helper, but it keeps getting reset at odd times
        Puppet[:bucketdir] = "/dev/null/bucket"

        @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
        @checksum = "md5:4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
        @dir = '/dev/null/bucket/4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0'

        @contents = "file contents"
    end

    it "should save a file" do
        ::File.expects(:exists?).with("#{@dir}/contents").returns false
        ::File.expects(:directory?).with(@dir).returns false
        ::FileUtils.expects(:mkdir_p).with(@dir)
        ::File.expects(:open).with("#{@dir}/contents",  ::File::WRONLY|::File::CREAT, 0440)

        bucketfile = Puppet::FileBucket::File.new(@contents)
        bucketfile.save

    end

    describe "using the indirector's find method" do
        it "should return nil if a file doesn't exist" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            bucketfile = Puppet::FileBucket::File.find("md5:#{@digest}")
            bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns true
            ::File.expects(:exists?).with("#{@dir}/paths").returns false
            ::File.expects(:read).with("#{@dir}/contents").returns @contents

            bucketfile = Puppet::FileBucket::File.find("md5:#{@digest}")
            bucketfile.should_not == nil
        end

        describe "using RESTish digest notation" do
            it "should return nil if a file doesn't exist" do
                ::File.expects(:exists?).with("#{@dir}/contents").returns false

                bucketfile = Puppet::FileBucket::File.find("md5/#{@digest}")
                bucketfile.should == nil
            end

            it "should find a filebucket if the file exists" do
                ::File.expects(:exists?).with("#{@dir}/contents").returns true
                ::File.expects(:exists?).with("#{@dir}/paths").returns false
                ::File.expects(:read).with("#{@dir}/contents").returns @contents

                bucketfile = Puppet::FileBucket::File.find("md5/#{@digest}")
                bucketfile.should_not == nil
            end

        end
    end

    it "should have a to_s method to return the contents" do
        Puppet::FileBucket::File.new(@contents).to_s.should == @contents
    end

    it "should have a method that returns the digest algorithm" do
        Puppet::FileBucket::File.new(@contents, :checksum => @checksum).checksum_type.should == :md5
    end

    it "should allow nil content" do
        proc { Puppet::FileBucket::File.new(nil) }.should_not raise_error(ArgumentError)
    end

    it "should raise an error if changing content" do
        x = Puppet::FileBucket::File.new(nil)
        x.contents = "first"
        proc { x.contents = "new" }.should raise_error(RuntimeError)
    end

    it "should require contents to be a string" do
        proc { Puppet::FileBucket::File.new(5) }.should raise_error(ArgumentError)
    end

    it "should raise an error if setting contents to a non-string" do
        x = Puppet::FileBucket::File.new(nil)
        proc { x.contents = 5 }.should raise_error(ArgumentError)
    end

    it "should set the contents appropriately" do
        Puppet::FileBucket::File.new(@contents).contents.should == @contents
    end

    it "should calculate the checksum" do
        Digest::MD5.expects(:hexdigest).with(@contents).returns('mychecksum')
        Puppet::FileBucket::File.new(@contents).checksum.should == 'md5:mychecksum'
    end

    it "should remove the old checksum value if the algorithm is changed" do
        Digest::MD5.expects(:hexdigest).with(@contents).returns('oldsum')
        sum = Puppet::FileBucket::File.new(@contents)
        oldsum = sum.checksum

        sum.checksum_type = :sha1
        Digest::SHA1.expects(:hexdigest).with(@contents).returns('newsum')
        sum.checksum.should == 'sha1:newsum'
    end

    it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
        Puppet::FileBucket::File.new(@contents).checksum_type.should == :md5
    end

    it "should support specifying the checksum_type during initialization" do
        sum = Puppet::FileBucket::File.new(@contents, :checksum_type => :sha1)
        sum.checksum_type.should == :sha1
    end

    it "should fail when an unsupported checksum_type is used" do
        proc { Puppet::FileBucket::File.new(@contents, :checksum_type => :nope) }.should raise_error(ArgumentError)
    end

    describe "when using back-ends" do
        it "should redirect using Puppet::Indirector" do
            Puppet::Indirector::Indirection.instance(:file_bucket_file).model.should equal(Puppet::FileBucket::File)
        end

        it "should have a :save instance method" do
            Puppet::FileBucket::File.new("mysum").should respond_to(:save)
        end

        it "should respond to :find" do
            Puppet::FileBucket::File.should respond_to(:find)
        end

        it "should respond to :destroy" do
            Puppet::FileBucket::File.should respond_to(:destroy)
        end
    end

    describe "when saving files" do
        it "should save the contents to the calculated path" do
            ::File.stubs(:directory?).with(@dir).returns(true)
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            mockfile = mock "file"
            mockfile.expects(:print).with(@contents)
            ::File.expects(:open).with("#{@dir}/contents", ::File::WRONLY|::File::CREAT, 0440).yields(mockfile)

            Puppet::FileBucket::File.new(@contents).save
        end

        it "should make any directories necessary for storage" do
            FileUtils.expects(:mkdir_p).with do |arg|
                ::File.umask == 0007 and arg == @dir
            end
            ::File.expects(:directory?).with(@dir).returns(false)
            ::File.expects(:open).with("#{@dir}/contents", ::File::WRONLY|::File::CREAT, 0440)
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            Puppet::FileBucket::File.new(@contents).save
        end
    end

    it "should accept a path" do
        remote_path = '/path/on/the/remote/box'
        Puppet::FileBucket::File.new(@contents, :path => remote_path).path.should == remote_path
    end

    it "should append the path to the paths file" do
        remote_path = '/path/on/the/remote/box'

        ::File.expects(:directory?).with(@dir).returns(true)
        ::File.expects(:open).with("#{@dir}/contents", ::File::WRONLY|::File::CREAT, 0440)
        ::File.expects(:exists?).with("#{@dir}/contents").returns false

        mockfile = mock "file"
        mockfile.expects(:puts).with('/path/on/the/remote/box')
        ::File.expects(:exists?).with("#{@dir}/paths").returns false
        ::File.expects(:open).with("#{@dir}/paths", ::File::WRONLY|::File::CREAT|::File::APPEND).yields mockfile
        Puppet::FileBucket::File.new(@contents, :path => remote_path).save

    end

    it "should return a url-ish name" do
        Puppet::FileBucket::File.new(@contents).name.should == "md5/4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
    end

    it "should return a url-ish name with a path" do
        Puppet::FileBucket::File.new(@contents, :path => 'my/path').name.should == "md5/4a8ec4fa5f01b4ab1a0ab8cbccb709f0/my/path"
    end

end
