#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:mode)
require 'tempfile'

describe property do
  before do
    @temp = Tempfile.new('mode')
    @path = @temp.path
    @file = Puppet::Type.type(:file).new(:name => @path, :backup => false)
  end

  def apply_resource(resource)
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource(resource)
    transaction = Puppet::Transaction.new(catalog)
    transaction.evaluate
    transaction.events
  end

  it "should set a mode symbolically" do
    @file[:mode] = "a+x"

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :mode_changed
    events.first.message.should == "mode changed '600' to '711' (a+x)"
    (File.stat(@path).mode & 07777).to_s(8).should == "711"
  end

  it "should set a mode symbolically, on a directory" do
    @temp.unlink
    Dir.mkdir(@path)
    File.chmod(0600, @path)

    @file[:mode] = "a+X,o-x"
    @file[:ensure] = "directory"

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :mode_changed
    events.first.message.should == "mode changed '600' to '710' (a+X,o-x)"
    (File.stat(@path).mode & 07777).to_s(8).should == "710"
  end


  it "should create a file with the correct permissions" do
    @temp.unlink
    @file[:mode]   = "555"
    @file[:ensure] = "present"

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :file_created
    events.first.message.should == "created"
    (File.stat(@path).mode & 07777).to_s(8).should == "555"
  end

  it "should create a file with the correct permissions when permissions are symbolic" do
    @temp.unlink
    @file[:mode]   = "a+x"
    @file[:ensure] = "present"

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :file_created
    events.first.message.should == "created"
    (File.stat(@path).mode & 07777).to_s(8).should == "111"
  end

  it "should create a directory with the correct permissions when permissions are symbolic" do
    @temp.unlink
    @file[:mode]   = "a+X"
    @file[:ensure] = "directory"

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :directory_created
    events.first.message.should == "created"
    (File.stat(@path).mode & 07777).to_s(8).should == "111"
  end

  it "should change a file into a directory with the correct permissions when permissions are symbolic" do
    @file[:mode] = "a+X"
    @file[:ensure] = "directory"

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :directory_created
    events.first.message.should == "ensure changed 'file' to 'directory'"
    (File.stat(@path).mode & 07777).to_s(8).should == "111"
  end

  it "should change a directory into a file with the correct permissions when permissions are symbolic" do
    @temp.unlink
    Dir.mkdir(@path)
    @file[:mode] = "u+x"
    @file[:ensure] = "file"
    @file[:force] = true # to allow removing directories

    events = apply_resource(@file)

    events.length.should == 1
    events.first.name.should == :file_created
    events.first.message.should == "ensure changed 'directory' to 'file'"
    (File.stat(@path).mode & 07777).to_s(8).should == "100"
  end
end
