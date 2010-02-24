#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/bucket_file'

describe Puppet::BucketFile do
    before do
        # this is the default from spec_helper, but it keeps getting reset at odd times
        Puppet[:bucketdir] = "/dev/null/bucket"

        @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
        @dir = '/dev/null/bucket/4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0'

        @contents = "file contents"
    end

    it "should save a file" do
        ::File.expects(:exists?).with("#{@dir}/contents").returns false
        ::File.expects(:directory?).with(@dir).returns false
        ::FileUtils.expects(:mkdir_p).with(@dir)
        ::File.expects(:open).with("#{@dir}/contents",  ::File::WRONLY|::File::CREAT, 0440)

        bucketfile = Puppet::BucketFile.new(@contents)
        bucketfile.save

    end

    describe "the find_by_checksum method" do
        it "should return nil if a file doesn't exist" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            bucketfile = Puppet::BucketFile.find_by_checksum("md5:#{@digest}")
            bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns true
            ::File.expects(:read).with("#{@dir}/contents").returns @contents

            bucketfile = Puppet::BucketFile.find_by_checksum("md5:#{@digest}")
            bucketfile.should_not == nil
        end

    end

    describe "using the indirector's find method" do 
        it "should return nil if a file doesn't exist" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            bucketfile = Puppet::BucketFile.find("md5:#{@digest}")
            bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
            ::File.expects(:exists?).with("#{@dir}/contents").returns true
            ::File.expects(:read).with("#{@dir}/contents").returns @contents

            bucketfile = Puppet::BucketFile.find("md5:#{@digest}")
            bucketfile.should_not == nil
        end

        describe "using RESTish digest notation" do
            it "should return nil if a file doesn't exist" do
                ::File.expects(:exists?).with("#{@dir}/contents").returns false

                bucketfile = Puppet::BucketFile.find("md5/#{@digest}")
                bucketfile.should == nil
            end

            it "should find a filebucket if the file exists" do
                ::File.expects(:exists?).with("#{@dir}/contents").returns true
                ::File.expects(:read).with("#{@dir}/contents").returns @contents

                bucketfile = Puppet::BucketFile.find("md5/#{@digest}")
                bucketfile.should_not == nil
            end

        end
    end

    it "should have a to_s method to return the contents"

    it "should have a method that returns the algorithm"

    it "should require content" do
        proc { Puppet::BucketFile.new(nil) }.should raise_error(ArgumentError)
    end

    it "should set the contents appropriately" do
        Puppet::BucketFile.new(@contents).contents.should == @contents
    end

    it "should calculate the checksum" do
        require 'digest/md5'
        Digest::MD5.expects(:hexdigest).with(@contents).returns('mychecksum')
        Puppet::BucketFile.new(@contents).checksum.should == 'md5:mychecksum'
    end

    it "should remove the old checksum value if the algorithm is changed" do
        Digest::MD5.expects(:hexdigest).with(@contents).returns('oldsum')
        sum = Puppet::BucketFile.new(@contents)
        oldsum = sum.checksum

        sum.checksum_type = :sha1
        Digest::SHA1.expects(:hexdigest).with(@contents).returns('newsum')
        sum.checksum.should == 'sha1:newsum'
    end

    it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
        Puppet::BucketFile.new(@contents).checksum_type.should == :md5
    end

    it "should support specifying the checksum_type during initialization" do
        sum = Puppet::BucketFile.new(@contents, :checksum_type => :sha1)
        sum.checksum_type.should == :sha1
    end

    it "should fail when an unsupported checksum_type is used" do
        proc { Puppet::BucketFile.new(@contents, :checksum_type => :nope) }.should raise_error(ArgumentError)
    end

    describe "when using back-ends" do
        it "should redirect using Puppet::Indirector" do
            Puppet::Indirector::Indirection.instance(:bucket_file).model.should equal(Puppet::BucketFile)
        end

        it "should have a :save instance method" do
            Puppet::BucketFile.new("mysum").should respond_to(:save)
        end

        it "should respond to :find" do
            Puppet::BucketFile.should respond_to(:find)
        end

        it "should respond to :destroy" do
            Puppet::BucketFile.should respond_to(:destroy)
        end
    end

    describe "when determining file paths" do
        it "should use the value of the :bucketdir setting as the root directory" do
            Puppet.stubs(:[]).with(:bucketdir).returns('/dev/null/bucketdir')
            Puppet::BucketFile.path_for('DEADBEEF').should =~ %r{^/dev/null/bucketdir}
        end

        it "should choose a path 8 directories deep with each directory name being the respective character in the filebucket" do
            Puppet.stubs(:[]).with(:bucketdir).returns('/dev/null/bucketdir')
            value = 'DEADBEEFC0FFEE'

            path = Puppet::BucketFile.path_for(value)
            dirs = value[0..7].split("").join(File::SEPARATOR)
            path.should be_include(dirs)
        end

        it "should use the full filebucket as the final directory name" do
            value = 'DEADBEEFC0FFEE'
            path = Puppet::BucketFile.path_for(value, 'contents')
            ::File.basename(::File.dirname(path)).should == value
        end

        it "should use 'contents' as the actual file name" do
            value = 'DEADBEEFC0FFEE'
            path = Puppet::BucketFile.path_for(value, 'contents')
            ::File.basename(path).should == "contents"
        end

        it "should use the bucketdir, the 8 sum character directories, the full filebucket, and 'contents' as the full file name" do
            Puppet.stubs(:[]).with(:bucketdir).returns('/dev/null/bucketdir')
            value = 'DEADBEEFC0FFEE'
            path = Puppet::BucketFile.path_for(value, 'contents')
            path.should == ['/dev/null/bucketdir', value[0..7].split(""), value, "contents"].flatten.join(::File::SEPARATOR)
        end
    end

    describe "when saving files" do
        it "should save the content to the calculated path" do
            path = Puppet::BucketFile.path_for(@digest, 'contents')

            ::File.stubs(:directory?).with(::File.dirname(path)).returns(true)
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            mockfile = mock "file"
            mockfile.expects(:print).with(@contents)
            ::File.expects(:open).with(path, ::File::WRONLY|::File::CREAT, 0440).yields(mockfile)

            Puppet::BucketFile.new(@contents).save
        end

        it "should make any directories necessary for storage" do
            path = Puppet::BucketFile.path_for(@digest, 'contents')

            FileUtils.expects(:mkdir_p).with do |arg|
                ::File.umask == 0007 and arg == ::File.dirname(path)
            end
            ::File.expects(:directory?).with(::File.dirname(path)).returns(false)
            ::File.expects(:open).with(path, ::File::WRONLY|::File::CREAT, 0440)
            ::File.expects(:exists?).with("#{@dir}/contents").returns false

            Puppet::BucketFile.new(@contents).save
        end
    end

    it "should accept a path" do 
        remote_path = '/path/on/the/remote/box'
        Puppet::BucketFile.new(@contents, :path => remote_path).path.should == remote_path
    end

    it "should append the path to the paths file" do
        remote_path = '/path/on/the/remote/box'

        save_path = Puppet::BucketFile.path_for(@digest, 'contents')
        ::File.expects(:directory?).with(::File.dirname(save_path)).returns(true)
        ::File.expects(:open).with(save_path, ::File::WRONLY|::File::CREAT, 0440)
        ::File.expects(:exists?).with("#{@dir}/contents").returns false

        mockfile = mock "file"
        mockfile.expects(:puts).with('/path/on/the/remote/box')
        ::File.expects(:exists?).with("#{@dir}/paths").returns false
        ::File.expects(:open).with("#{@dir}/paths", ::File::WRONLY|::File::CREAT|::File::APPEND).yields mockfile
        Puppet::BucketFile.new(@contents, :path => remote_path).save

    end
    
    it "should load the paths" do
        paths = ["path1", "path2"]
        ::File.expects(:exists?).with("#{@dir}/paths").returns true

        mockfile = mock "file"
        mockfile.expects(:readlines).returns( paths )
        ::File.expects(:open).with("#{@dir}/paths").yields mockfile

        Puppet::BucketFile.new(@contents).paths.should == paths
    end

    it "should return a url-ish name" do
        Puppet::BucketFile.new(@contents).name.should == "md5/4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
    end

    it "should return a url-ish name with a path" do
        Puppet::BucketFile.new(@contents, :path => 'my/path').name.should == "md5/4a8ec4fa5f01b4ab1a0ab8cbccb709f0/my/path"
    end


end
