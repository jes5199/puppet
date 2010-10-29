#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/resource/catalog'

Puppet::Resource::Catalog.indirection.terminus(:compiler)

describe Puppet::Resource::Catalog::Compiler do
end
