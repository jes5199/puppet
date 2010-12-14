#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet_spec/files'

require 'puppet/transaction/resource_harness'

describe Puppet::Transaction::ResourceHarness do
  include PuppetSpec::Files

  before do
    @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
    @resource = Puppet::Type.type(:file).new :path => "/my/file"
    @harness = Puppet::Transaction::ResourceHarness.new(@transaction)
    @current_state = Puppet::Resource.new(:file, "/my/file")
    @resource.stubs(:retrieve).returns @current_state
    @status = Puppet::Resource::Status.new(@resource)
    Puppet::Resource::Status.stubs(:new).returns @status
  end

  it "should accept a transaction at initialization" do
    harness = Puppet::Transaction::ResourceHarness.new(@transaction)
    harness.transaction.should equal(@transaction)
  end

  it "should delegate to the transaction for its relationship graph" do
    @transaction.expects(:relationship_graph).returns "relgraph"
    Puppet::Transaction::ResourceHarness.new(@transaction).relationship_graph.should == "relgraph"
  end

  describe "when evaluating a resource" do
    it "should create and return a resource status instance for the resource" do
      @harness.evaluate(@resource).should be_instance_of(Puppet::Resource::Status)
    end

    it "should fail if no status can be created" do
      Puppet::Resource::Status.expects(:new).raises ArgumentError

      lambda { @harness.evaluate(@resource) }.should raise_error
    end

    it "should retrieve the current state of the resource" do
      @resource.expects(:retrieve).returns @current_state
      @harness.evaluate(@resource)
    end

    it "should mark the resource as failed and return if the current state cannot be retrieved" do
      @resource.expects(:retrieve).raises ArgumentError
      @harness.evaluate(@resource).should be_failed
    end

    it "should store the resource's evaluation time in the resource status" do
      @harness.evaluate(@resource).evaluation_time.should be_instance_of(Float)
    end
  end

  describe "when creating changes" do
    before do
      @current_state = Puppet::Resource.new(:file, "/my/file")
      @resource.stubs(:retrieve).returns @current_state
      Puppet.features.stubs(:root?).returns true
    end
  end

  describe "when applying changes" do
    before do
      @change1 = stub 'change1', :apply => stub("event", :status => "success"), :auditing? => false
      @change2 = stub 'change2', :apply => stub("event", :status => "success"), :auditing? => false
      @changes = [@change1, @change2]
    end

    describe "when there's not an existing audited value" do
      it "should save the old value before applying the change if it's audited" do
        test_file = tmpfile('foo')
        File.open(test_file, "w", 0750).close

        resource = Puppet::Type.type(:file).new :path => test_file, :mode => '755', :audit => :mode

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == "750"

        (File.stat(test_file).mode & 0777).should == 0755
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/mode: mode changed '750' to '755'",
          "notice: /#{resource}/mode: audit change: newly-recorded value 750"
        ]
      end

      it "should audit the value if there's no change" do
        test_file = tmpfile('foo')
        File.open(test_file, "w", 0755).close

        resource = Puppet::Type.type(:file).new :path => test_file, :mode => '755', :audit => :mode

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == "755"

        (File.stat(test_file).mode & 0777).should == 0755

        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/mode: audit change: newly-recorded value 755"
        ]
      end

      it "should have :absent for audited value if the file doesn't exist" do
        test_file = tmpfile('foo')

        resource = Puppet::Type.type(:file).new :ensure => 'present', :path => test_file, :mode => '755', :audit => :mode

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == :absent

        (File.stat(test_file).mode & 0777).should == 0755
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/ensure: created",
          "notice: /#{resource}/mode: audit change: newly-recorded value absent"
        ]
      end

      it "should do nothing if there are no changes to make and the stored value is correct" do
        test_file = tmpfile('foo')

        resource = Puppet::Type.type(:file).new :path => test_file, :mode => '755', :audit => :mode, :ensure => 'absent'
        @harness.cache(resource, :mode, :absent)

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == :absent

        File.exists?(test_file).should == false
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ []
      end
    end

    describe "when there's an existing audited value" do
      it "should save the old value before applying the change" do
        test_file = tmpfile('foo')
        File.open(test_file, "w", 0750).close

        resource = Puppet::Type.type(:file).new :path => test_file, :audit => :mode
        @harness.cache(resource, :mode, '555')

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == "750"

        (File.stat(test_file).mode & 0777).should == 0750
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/mode: audit change: previously recorded value 555 has been changed to 750"
        ]
      end

      it "should save the old value before applying the change" do
        test_file = tmpfile('foo')
        File.open(test_file, "w", 0750).close

        resource = Puppet::Type.type(:file).new :path => test_file, :mode => '755', :audit => :mode
        @harness.cache(resource, :mode, '555')

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == "750"

        (File.stat(test_file).mode & 0777).should == 0755
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/mode: mode changed '750' to '755' (previously recorded value was 555)"
        ]
      end

      it "should audit the value if there's no change" do
        test_file = tmpfile('foo')
        File.open(test_file, "w", 0755).close

        resource = Puppet::Type.type(:file).new :path => test_file, :mode => '755', :audit => :mode
        @harness.cache(resource, :mode, '555')

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == "755"

        (File.stat(test_file).mode & 0777).should == 0755
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/mode: audit change: previously recorded value 555 has been changed to 755"
        ]
      end

      it "should have :absent for audited value if the file doesn't exist" do
        test_file = tmpfile('foo')

        resource = Puppet::Type.type(:file).new :ensure => 'present', :path => test_file, :mode => '755', :audit => :mode
        @harness.cache(resource, :mode, '555')

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == :absent

        (File.stat(test_file).mode & 0777).should == 0755

        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ [
          "notice: /#{resource}/ensure: created", "notice: /#{resource}/mode: audit change: previously recorded value 555 has been changed to absent"
        ]
      end

      it "should do nothing if there are no changes to make and the stored value is correct" do
        test_file = tmpfile('foo')
        File.open(test_file, "w", 0755).close

        resource = Puppet::Type.type(:file).new :path => test_file, :mode => '755', :audit => :mode
        @harness.cache(resource, :mode, '755')

        @harness.evaluate(resource)
        @harness.cached(resource, :mode).should == "755"

        (File.stat(test_file).mode & 0777).should == 0755
        @logs.map {|l| "#{l.level}: #{l.source}: #{l.message}"}.should =~ []
      end
    end
  end

  describe "when determining whether the resource can be changed" do
    before do
      @resource.stubs(:purging?).returns true
      @resource.stubs(:deleting?).returns true
    end

    it "should be true if the resource is not being purged" do
      @resource.expects(:purging?).returns false
      @harness.should be_allow_changes(@resource)
    end

    it "should be true if the resource is not being deleted" do
      @resource.expects(:deleting?).returns false
      @harness.should be_allow_changes(@resource)
    end

    it "should be true if the resource has no dependents" do
      @harness.relationship_graph.expects(:dependents).with(@resource).returns []
      @harness.should be_allow_changes(@resource)
    end

    it "should be true if all dependents are being deleted" do
      dep = stub 'dependent', :deleting? => true
      @harness.relationship_graph.expects(:dependents).with(@resource).returns [dep]
      @resource.expects(:purging?).returns true
      @harness.should be_allow_changes(@resource)
    end

    it "should be false if the resource's dependents are not being deleted" do
      dep = stub 'dependent', :deleting? => false, :ref => "myres"
      @resource.expects(:warning)
      @harness.relationship_graph.expects(:dependents).with(@resource).returns [dep]
      @harness.should_not be_allow_changes(@resource)
    end
  end

  describe "when finding the schedule" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
    end

    it "should warn and return nil if the resource has no catalog" do
      @resource.catalog = nil
      @resource.expects(:warning)

      @harness.schedule(@resource).should be_nil
    end

    it "should return nil if the resource specifies no schedule" do
      @harness.schedule(@resource).should be_nil
    end

    it "should fail if the named schedule cannot be found" do
      @resource[:schedule] = "whatever"
      @resource.expects(:fail)
      @harness.schedule(@resource)
    end

    it "should return the named schedule if it exists" do
      sched = Puppet::Type.type(:schedule).new(:name => "sched")
      @catalog.add_resource(sched)
      @resource[:schedule] = "sched"
      @harness.schedule(@resource).to_s.should == sched.to_s
    end
  end

  describe "when determining if a resource is scheduled" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @resource.catalog = @catalog
      @status = Puppet::Resource::Status.new(@resource)
    end

    it "should return true if 'ignoreschedules' is set" do
      Puppet[:ignoreschedules] = true
      @resource[:schedule] = "meh"
      @harness.should be_scheduled(@status, @resource)
    end

    it "should return true if the resource has no schedule set" do
      @harness.should be_scheduled(@status, @resource)
    end

    it "should return the result of matching the schedule with the cached 'checked' time if a schedule is set" do
      t = Time.now
      @harness.expects(:cached).with(@resource, :checked).returns(t)

      sched = Puppet::Type.type(:schedule).new(:name => "sched")
      @catalog.add_resource(sched)
      @resource[:schedule] = "sched"

      sched.expects(:match?).with(t.to_i).returns "feh"

      @harness.scheduled?(@status, @resource).should == "feh"
    end
  end

  it "should be able to cache data in the Storage module" do
    data = {}
    Puppet::Util::Storage.expects(:cache).with(@resource).returns data
    @harness.cache(@resource, :foo, "something")

    data[:foo].should == "something"
  end

  it "should be able to retrieve data from the cache" do
    data = {:foo => "other"}
    Puppet::Util::Storage.expects(:cache).with(@resource).returns data
    @harness.cached(@resource, :foo).should == "other"
  end
end
