#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

provider = Puppet::Type.type(:package).provider(:rug)

describe provider do
    before do
        @resource = stub 'resource', :[] => "asdf"
        @provider = provider.new(@resource)
    end


    describe "when determining latest available version" do

        it "should cope with names containing ++" do
            @resource = stub 'resource', :[] => "asdf++"
            @provider = provider.new(@resource)
            @provider.expects(:rug).returns "asdf++ | 1.0"
            @provider.latest.should == "1.0"
        end

    end

end
