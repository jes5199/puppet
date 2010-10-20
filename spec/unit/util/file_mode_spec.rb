#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/file_mode'

describe Puppet::Util::FileMode do
  describe ".bits_for_mode" do
    it "should return an integer if it was passed digits" do
      Puppet::Util::FileMode.bits_for_mode("0654").to_s(8).should == "654"
    end

    it "should understand u+r" do
      Puppet::Util::FileMode.bits_for_mode("u+r").to_s(8).should == "400"
    end

    it "should understand g+r" do
      Puppet::Util::FileMode.bits_for_mode("g+r").to_s(8).should == "40"
    end

    it "should understand a+r" do
      Puppet::Util::FileMode.bits_for_mode("a+r").to_s(8).should == "444"
    end

    it "should understand a+x" do
      Puppet::Util::FileMode.bits_for_mode("a+x").to_s(8).should == "111"
    end

    it "should understand a+t" do
      Puppet::Util::FileMode.bits_for_mode("o+t").to_s(8).should == "1000"
    end

    it "should understand o+t" do
      Puppet::Util::FileMode.bits_for_mode("o+t").to_s(8).should == "1000"
    end

    it "should understand o-t" do
      Puppet::Util::FileMode.bits_for_mode("o-t",07777).to_s(8).should == "6777"
    end

    it "should understand a-x" do
      Puppet::Util::FileMode.bits_for_mode("a-x",07777).to_s(8).should == "7666"
    end

    it "should understand a-rwx" do
      Puppet::Util::FileMode.bits_for_mode("a-rwx",07777).to_s(8).should == "7000"
    end

    it "should understand ug-rwx" do
      Puppet::Util::FileMode.bits_for_mode("ug-rwx",07777).to_s(8).should == "7007"
    end

    it "should understand a+x,ug-rwx" do
      Puppet::Util::FileMode.bits_for_mode("a+x,ug-rwx").to_s(8).should == "1"
    end

    it "should understand a+g" do
      # My experimentation on debian suggests that +g ignores the sgid flag
      Puppet::Util::FileMode.bits_for_mode("a+g", 02060).to_s(8).should == "2666"
    end

    it "should understand a-g" do
      # My experimentation on debian suggests that -g ignores the sgid flag
      Puppet::Util::FileMode.bits_for_mode("a-g", 02666).to_s(8).should == "2000"
    end

    it "should understand g+x,a+g" do
      Puppet::Util::FileMode.bits_for_mode("g+x,a+g").to_s(8).should == "111"
    end

    it "should understand u+x,g+X" do
      Puppet::Util::FileMode.bits_for_mode("u+x,g+X").to_s(8).should == "110"
    end

    it "should understand g+X" do
      Puppet::Util::FileMode.bits_for_mode("g+X").to_s(8).should == "0"
    end

  end

end
