#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_bucket/dipper'
describe Puppet::FileBucket::Dipper do
  before do
    ['/my/file'].each do |x|
      Puppet::FileBucket::Dipper.any_instance.stubs(:absolutize_path).with(x).returns(x)
    end
  end

  it "should fail in an informative way when there are failures backing up to the server" do
    File.stubs(:exist?).returns true
    File.stubs(:read).returns "content"

    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    Puppet::FileBucket::File.default_route.stubs(:save).raises ArgumentError

    lambda { @dipper.backup("/my/file") }.should raise_error(Puppet::Error)
  end

  it "should backup files to a local bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(
      :Path => "/my/bucket"
    )

    File.stubs(:exist?).returns true
    File.stubs(:read).with("/my/file").returns "my contents"

    Puppet::FileBucket::File.default_route.stubs(:save).with{|key, instance| key == 'md5/2975f560750e71c478b8e3b39a956adb//my/file' and instance.contents == "my contents" }

    @dipper.backup("/my/file").should == "2975f560750e71c478b8e3b39a956adb"
  end

  it "should retrieve files from a local bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(
      :Path => "/my/bucket"
    )

    File.stubs(:exist?).returns true
    File.stubs(:read).with("/my/file").returns "my contents"

    bucketfile = stub "bucketfile"
    bucketfile.stubs(:to_s).returns "Content"

    Puppet::FileBucket::File.default_route.expects(:find).with{|x,opts|
      x == 'md5/DIGEST123'
    }.returns(bucketfile)

    @dipper.getfile("DIGEST123").should == "Content"
  end

  it "should backup files to a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(
      :Server => "puppetmaster",
      :Port   => "31337"
    )

    File.stubs(:exist?).returns true
    File.stubs(:read).with("/my/file").returns "my contents"

    bucketfile = stub "bucketfile"
    bucketfile.stubs(:name).returns('md5/DIGEST123')
    bucketfile.stubs(:checksum_data).returns("DIGEST123")
    Puppet::FileBucket::File.make_route(:rest).expects(:save).with('https://puppetmaster:31337/production/file_bucket_file/md5/DIGEST123', bucketfile)

    Puppet::FileBucket::File.stubs(:new).with(
      "my contents",
      :bucket_path => nil,
        
      :path => '/my/file'
    ).returns(bucketfile)

    @dipper.backup("/my/file").should == "DIGEST123"
  end

  it "should retrieve files from a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(
      :Server => "puppetmaster",
      :Port   => "31337"
    )

    File.stubs(:exist?).returns true
    File.stubs(:read).with("/my/file").returns "my contents"

    bucketfile = stub "bucketfile"
    bucketfile.stubs(:to_s).returns "Content"

    Puppet::FileBucket::File.make_route(:rest).expects(:find).with{|x,opts|
      x == 'https://puppetmaster:31337/production/file_bucket_file/md5/DIGEST123'
    }.returns(bucketfile)

    @dipper.getfile("DIGEST123").should == "Content"
  end


end
