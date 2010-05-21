#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Expression::Relationship do
  before do
    @class = Puppet::Parser::Expression::Relationship
  end

  it "should set its 'left' and 'right' arguments accordingly" do
    dep = @class.new(:left, :right, '->')
    dep.left.should == :left
    dep.right.should == :right
  end

  it "should set its arrow to whatever arrow is passed" do
    @class.new(:left, :right, '->').arrow.should == '->'
  end

  it "should set its type to :relationship if the relationship type is '<-'" do
    @class.new(:left, :right, '<-').type.should == :relationship
  end

  it "should set its type to :relationship if the relationship type is '->'" do
    @class.new(:left, :right, '->').type.should == :relationship
  end

  it "should set its type to :subscription if the relationship type is '~>'" do
    @class.new(:left, :right, '~>').type.should == :subscription
  end

  it "should set its type to :subscription if the relationship type is '<~'" do
    @class.new(:left, :right, '<~').type.should == :subscription
  end

  it "should set its line and file if provided" do
    dep = @class.new(:left, :right, '->', :line => 50, :file => "/foo")
    dep.line.should == 50
    dep.file.should == "/foo"
  end

  describe "when evaluating" do
    before do
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
      @scope = Puppet::Parser::Scope.new(:compiler => @compiler)
    end

    it "should create a relationship with the evaluated source and target and add it to the scope" do
      source = stub 'source', :denotation => :left
      target = stub 'target', :denotation => :right
      @class.new(source, target, '->').compute_denotation(@scope)
      @compiler.relationships[0].source.should == :left
      @compiler.relationships[0].target.should == :right
    end

    describe "a chained relationship" do
      before do
        @left = stub 'left', :denotation => :left
        @middle = stub 'middle', :denotation => :middle
        @right = stub 'right', :denotation => :right
        @first = @class.new(@left, @middle, '->')
        @second = @class.new(@first, @right, '->')
      end

      it "should evaluate the relationship to the left" do
        @first.expects(:compute_denotation).with(@scope).returns Puppet::Parser::Relationship.new(:left, :right, :relationship)

        @second.compute_denotation(@scope)
      end

      it "should use the right side of the left relationship as its source" do
        @second.compute_denotation(@scope)

        @compiler.relationships[0].source.should == :left
        @compiler.relationships[0].target.should == :middle
        @compiler.relationships[1].source.should == :middle
        @compiler.relationships[1].target.should == :right
      end

      it "should only evaluate a given Expression node once" do
        @left.expects(:denotation).once.returns :left
        @middle.expects(:denotation).once.returns :middle
        @right.expects(:denotation).once.returns :right
        @second.compute_denotation(@scope)
      end
    end
  end
end
