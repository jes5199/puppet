#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/bucket_file'

describe Puppet::BucketFile do
    before do
        # this is the default from spec_helper, but it keeps getting reset at odd times
        Puppet[:bucketdir] = "/dev/null/bucket"

        @dir = '/dev/null/bucket/d/a/6/1/9/d/f/b/da619dfbf5572fc749b1496b0fffd76a'
    end

    it "should save a file" do
        ::File.expects(:exists?).with("#{@dir}/contents").returns false
        ::File.expects(:directory?).with(@dir).returns false
        ::FileUtils.expects(:mkdir_p).with(@dir)
        ::File.expects(:open).with("#{@dir}/contents",  ::File::WRONLY|::File::CREAT, 0440)

        bucketfile = Puppet::BucketFile.new("the content")
        bucketfile.save

    end

    describe "the find_by_hash method" do
        it "should return nil if a file doesn't exist" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            bucketfile = Puppet::BucketFile.find_by_hash("md5:da619dfbf5572fc749b1496b0fffd76a")
            bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns true
            ::File.expects(:read).with("#{@dir}/contents").returns "the content"

            bucketfile = Puppet::BucketFile.find_by_hash("md5:da619dfbf5572fc749b1496b0fffd76a")
            bucketfile.should_not == nil
        end

    end

    describe "using the indirector's find method" do 
        it "should return nil if a file doesn't exist" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            bucketfile = Puppet::BucketFile.find("md5:da619dfbf5572fc749b1496b0fffd76a")
            bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns true
            ::File.expects(:read).with("#{@dir}/contents").returns "the content"

            bucketfile = Puppet::BucketFile.find("md5:da619dfbf5572fc749b1496b0fffd76a")
            bucketfile.should_not == nil
        end

        describe "using RESTish digest notation" do
            it "should return nil if a file doesn't exist" do
                ::File.expects(:exists?).with("#{@dir}/contents").returns false

                bucketfile = Puppet::BucketFile.find("md5/da619dfbf5572fc749b1496b0fffd76a")
                bucketfile.should == nil
            end

            it "should find a filebucket if the file exists" do
                ::File.expects(:exists?).with("#{@dir}/contents").returns true
                ::File.expects(:read).with("#{@dir}/contents").returns "the content"

                bucketfile = Puppet::BucketFile.find("md5/da619dfbf5572fc749b1496b0fffd76a")
                bucketfile.should_not == nil
            end

        end
    end
end

if false
    it "should have a to_s method to return the contents"

    it "should have a method that returns the algorithm"


    it "should require content" do
        proc { Puppet::Checksum.new(nil) }.should raise_error(ArgumentError)
    end

    it "should set the content appropriately" do
        @sum.content.should == @content
    end

    it "should calculate the checksum" do
        require 'digest/md5'
        Digest::MD5.expects(:hexdigest).with(@content).returns(:mychecksum)
        @sum.checksum.should == :mychecksum
    end

    it "should not calculate the checksum until it is asked for" do
        require 'digest/md5'
        Digest::MD5.expects(:hexdigest).never
        sum = Puppet::Checksum.new(@content, :md5)
    end

    it "should remove the old checksum value if the algorithm is changed" do
        Digest::MD5.expects(:hexdigest).with(@content).returns(:oldsum)
        oldsum = @sum.checksum
        @sum.algorithm = :sha1
        Digest::SHA1.expects(:hexdigest).with(@content).returns(:newsum)
        @sum.checksum.should == :newsum
    end

    it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
        @sum.algorithm.should == :md5
    end

    it "should support specifying the algorithm during initialization" do
        sum = Puppet::Checksum.new(@content, :sha1)
        sum.algorithm.should == :sha1
    end

    it "should fail when an unsupported algorithm is used" do
        proc { Puppet::Checksum.new(@content, :nope) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Checksum, " when using back-ends" do
    it "should redirect using Puppet::Indirector" do
        Puppet::Indirector::Indirection.instance(:checksum).model.should equal(Puppet::Checksum)
    end

    it "should have a :save instance method" do
        Puppet::Checksum.new("mysum").should respond_to(:save)
    end

    it "should respond to :find" do
        Puppet::Checksum.should respond_to(:find)
    end

    it "should respond to :destroy" do
        Puppet::Checksum.should respond_to(:destroy)
    end
end

    raise "TODO" # TODO
        describe Puppet::Indirector::BucketFile::File, " when determining file paths" do

            # I was previously passing the object in.
            it "should use the value passed in to path() as the filebucket" do
                @value.expects(:name).never
                @store.path(@value)
            end

            it "should use the value of the :bucketdir setting as the root directory" do
                @path.should =~ %r{^#{@dir}}
            end

            it "should choose a path 8 directories deep with each directory name being the respective character in the filebucket" do
                dirs = @value[0..7].split("").join(File::SEPARATOR)
                @path.should be_include(dirs)
            end

            it "should use the full filebucket as the final directory name" do
                ::File.basename(::File.dirname(@path)).should == @value
            end

            it "should use 'contents' as the actual file name" do
                ::File.basename(@path).should == "contents"
            end

            it "should use the bucketdir, the 8 sum character directories, the full filebucket, and 'contents' as the full file name" do
                @path.should == [@dir, @value[0..7].split(""), @value, "contents"].flatten.join(::File::SEPARATOR)
            end
        end



        describe Puppet::Indirector::BucketFile::File, " when saving files" do

            # LAK:FIXME I don't know how to include in the spec the fact that we're
            # using the superclass's save() method and thus are acquiring all of
            # it's behaviours.
            it "should save the content to the calculated path" do
                ::File.stubs(:directory?).with(::File.dirname(@path)).returns(true)
                ::File.expects(:open).with(@path, "w")

                file = stub 'file', :name => @digest
                @store.save(@request)
            end

            it "should make any directories necessary for storage" do
                FileUtils.expects(:mkdir_p).with do |arg|
                    ::File.umask == 0007 and arg == ::File.dirname(@path)
                end
                ::File.expects(:directory?).with(::File.dirname(@path)).returns(true)
                ::File.expects(:open).with(@path, "w")

                @store.save(@request)
            end
        end

end
