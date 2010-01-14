#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

describe Puppet::Type.type(:cron).provider(:crontab) do
    before :each do
        @cron_type = Puppet::Type.type(:cron)
        @provider = @cron_type.provider(:crontab)
    end

    it "should round-trip the name as a comment for @special events" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
@reboot /bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        @provider.to_line(prefetch[0]).should =~ /Puppet Name: test/
    end

    it "should round-trip the name as a comment for scheduled events" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
17 *	* * *	/bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        @provider.to_line(prefetch[0]).should =~ /Puppet Name: test/
    end

    it "should round-trip the schedule for scheduled events" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
17 *	* * *	/bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        @provider.to_line(prefetch[0]).should be_include("17 * * * * /bin/echo > /tmp/puppet.txt")
    end

    it "should set all of the time fields for scheduled events" do
        resource = {
            :record_type => :crontab,
            :minute      => 1,
            :hour        => 2,
            :monthday    => 3,
            :month       => 4,
            :weekday     => 5,
            :command     => "/bin/true",
        }
        @provider.to_line(resource).should == "1 2 3 4 5 /bin/true"
    end

    it "should output * for absent time fields" do
        resource = {
            :record_type => :crontab,
            :minute      => 1,
            :hour        => :absent,
            :monthday    => '*',
            # skipping month
            :weekday     => nil,
            :command     => "/bin/true",
        }
        @provider.to_line(resource).should == "1 * * * * /bin/true"
    end

    it "should output environments for scheduled events" do
        resource = {
            :record_type => :crontab,
            :minute      => 1,
            :hour        => :absent,
            :monthday    => '*',
            # skipping month
            :weekday     => nil,
            :command     => "/bin/true",
            :environment => "ENV=1",
            :name        => "name",
        }
        @provider.to_line(resource).should == "# Puppet Name: name\nENV=1\n1 * * * * /bin/true"
    end

    it "should output special events correctly" do
        resource = {
            :record_type => :crontab,
            :special     => "reboot",
            :minute      => 1,
            :hour        => 2,
            :monthday    => 3,
            :month       => 4,
            :weekday     => 5,
            :command     => "/bin/true",
        }
        @provider.to_line(resource).should == "@reboot /bin/true"
    end

    it "should output environments for special events" do
        resource = {
            :record_type => :crontab,
            :special     => "reboot",
            :command     => "/bin/true",
            :environment => "ENV=1",
            :name        => "name",
        }
        @provider.to_line(resource).should == "# Puppet Name: name\nENV=1\n@reboot /bin/true"
    end

    it "should parse named @special events" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
@reboot /bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{
            :record_type => :crontab,
            :special     => "reboot",

            :minute      => nil,
            :hour        => nil,
            :monthday    => nil,
            :month       => nil,
            :weekday     => nil,

            :environment => :absent,
            :name        => 'test',

            :command     => "/bin/echo > /tmp/puppet.txt"
        }]
    end

    it "should parse named @special events with an environment" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
VAR=environment
@reboot /bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{
            :record_type => :crontab,
            :special     => "reboot",

            :minute      => nil,
            :hour        => nil,
            :monthday    => nil,
            :month       => nil,
            :weekday     => nil,

            :environment => ["VAR=environment"],
            :name        => 'test',

            :command     => "/bin/echo > /tmp/puppet.txt"
        }]
    end

    it "should parse named scheduled events" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
1 2	3 4 5	/bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{
            :record_type => :crontab,
            :special     => nil,

            :minute      => ["1"],
            :hour        => ["2"],
            :monthday    => ["3"],
            :month       => ["4"],
            :weekday     => ["5"],

            :environment => :absent,
            :name        => 'test',

            :command     => "/bin/echo > /tmp/puppet.txt"
        }]
    end

    it "should parse named scheduled events with an environment" do
        parse = @provider.parse <<-CRON
# Puppet Name: test
VAR=environment
1 2	3 4 5	/bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{
            :record_type => :crontab,
            :special     => nil,

            :minute      => ["1"],
            :hour        => ["2"],
            :monthday    => ["3"],
            :month       => ["4"],
            :weekday     => ["5"],

            :environment => ["VAR=environment"],
            :name        => 'test',

            :command     => "/bin/echo > /tmp/puppet.txt"
        }]
    end

    it "should parse anonymous @special events" do
        parse = @provider.parse <<-CRON
@reboot /bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{
            :record_type => :crontab,
            :special     => "reboot",

            :minute      => nil,
            :hour        => nil,
            :monthday    => nil,
            :month       => nil,
            :weekday     => nil,

            :environment => :absent,

            :command     => "/bin/echo > /tmp/puppet.txt"
        }]
    end

    it "should parse anonymous scheduled events" do
        parse = @provider.parse <<-CRON
1 *	2 * 3	/bin/echo > /tmp/puppet.txt
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{
            :record_type => :crontab,
            :special     => nil,

            :minute      => ["1"],
            :hour        => :absent,
            :monthday    => ["2"],
            :month       => :absent,
            :weekday     => ["3"],

            :environment => :absent,

            :command     => "/bin/echo > /tmp/puppet.txt"
        }]

    end

    it "should parse non-name comments as comments" do
        parse = @provider.parse <<-CRON
# This is a comment
        CRON
        prefetch = @provider.prefetch_hook(parse)

        prefetch.should == [{:line=>"# This is a comment", :record_type=>:comment}]
    end

end
