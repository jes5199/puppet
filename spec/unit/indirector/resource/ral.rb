#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "Puppet::Resource::Ral" do
    describe "find" do
        before do
            @request = stub 'request', :key => "user/root"
        end

        it "should find an existing instance" do
            my_resource    = stub "my user resource"

            wrong_instance = stub "wrong user", :name => "bob"
            my_instance    = stub "my user",    :name => "root", :to_resource => my_resource

            require 'puppet/type/user'
            Puppet::Type::User.expects(:instances).returns([ wrong_instance, my_instance, wrong_instance ])
            Puppet::Resource::Ral.new.find(@request).should == my_resource
        end

        it "if there is no instance, it should create one" do
            wrong_instance = stub "wrong user", :name => "bob"

            require 'puppet/type/user'
            Puppet::Type::User.expects(:instances).returns([ wrong_instance, wrong_instance ])
            Puppet::Resource::Ral.new.find(@request).should == 1
        end
    end

    describe "search" do
        it
    end

    describe "save" do
        it
    end
end
