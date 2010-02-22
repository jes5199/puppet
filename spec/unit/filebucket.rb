#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/filebucket'

describe Puppet::Filebucket do
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

        bucketfile = Puppet::Filebucket.new("the content")
        bucketfile.save

    end

    it "should return nil if a file doesn't exist" do
        ::File.expects(:exists?).with("#{@dir}/contents").returns false

        bucketfile = Puppet::Filebucket.find("md5:da619dfbf5572fc749b1496b0fffd76a")
        bucketfile.should == nil
    end

    it "should find a filebucket if the file exists" do
        ::File.expects(:exists?).with("#{@dir}/contents").returns true
        ::File.expects(:read).with("#{@dir}/contents").returns "the content"

        bucketfile = Puppet::Filebucket.find("md5:da619dfbf5572fc749b1496b0fffd76a")
        bucketfile.should_not == nil
    end
end

if false
    raise "TODO" # TODO
        describe Puppet::Indirector::Filebucket::File, " when determining file paths" do

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



        describe Puppet::Indirector::Filebucket::File, " when saving files" do

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
