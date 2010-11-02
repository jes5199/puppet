#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

describe "Puppet::FileServing::Files", :shared => true do
  it "should use the configuration to test whether the request is allowed" do
    uri = "fakemod/my/file"
    mount = mock 'mount'
    config = stub 'configuration', :split_path => [mount, "eh"]
    @indirection.terminus(:file_server).stubs(:configuration).returns config
    mount.expects(:allowed?).returns(true)
    mount.expects(:find).returns(nil)
    @test_class.find(uri, :node => "foo", :ip => "bar")
  end
end
