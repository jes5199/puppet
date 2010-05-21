#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::ResourceReference do

  ast = Puppet::Parser::Expression

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  def newref(type, title)
    title = stub 'title', :denotation => title
    ref = Puppet::Parser::Expression::ResourceReference.new(:scope => ((@scope)), :type => type, :title => title)
  end

  it "should correctly produce reference strings" do
    newref("File", "/tmp/yay").compute_denotation.to_s.should == "File[/tmp/yay]"
  end

  it "should produce a single resource when the title evaluates to a string" do
    newref("File", "/tmp/yay").compute_denotation.should == Puppet::Resource.new("file", "/tmp/yay")
  end

  it "should return an array of resources if given an array of titles" do
    titles = mock 'titles', :denotation => ["title1","title2"]
    ref = ast::ResourceReference.new( :title => titles, :type => "File" )
    ref.compute_denotation.should == [
      Puppet::Resource.new("file", "title1"),
      Puppet::Resource.new("file", "title2")
    ]
  end

  it "should pass its scope's namespaces to all created resource references" do
    @scope.add_namespace "foo"
    newref("File", "/tmp/yay").compute_denotation.namespaces.should == ["foo"]
  end

  it "should return a correct representation when converting to string" do
    type = stub 'type', :is_a? => true, :to_s => "file"
    title = stub 'title', :is_a? => true, :to_s => "[/tmp/a, /tmp/b]"

    ast::ResourceReference.new( :type => type, :title => title ).to_s.should == "File[/tmp/a, /tmp/b]"
  end
end
