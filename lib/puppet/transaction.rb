# the class that actually walks our resource/property tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/util/tagging'
require 'puppet/application'
require 'sha1'

class Puppet::Transaction
  require 'puppet/transaction/event'
  require 'puppet/transaction/event_manager'
  require 'puppet/transaction/resource_harness'
  require 'puppet/resource/status'

  attr_accessor :component, :catalog, :ignoreschedules
  attr_accessor :configurator

  # The report, once generated.
  attr_accessor :report

  # Routes and stores any events and subscriptions.
  attr_reader :event_manager

  # Handles most of the actual interacting with resources
  attr_reader :resource_harness

  include Puppet::Util
  include Puppet::Util::Tagging

  # Wraps application run state check to flag need to interrupt processing
  def stop_processing?
    Puppet::Application.stop_requested?
  end

  # Add some additional times for reporting
  def add_times(hash)
    hash.each do |name, num|
      report.add_times(name, num)
    end
  end

  # Are there any failed resources in this transaction?
  def any_failed?
    report.resource_statuses.values.detect { |status| status.failed? }
  end

  # Apply all changes for a resource
  def apply(resource, ancestor = nil)
    status = resource_harness.evaluate(resource)
    add_resource_status(status)
    event_manager.queue_events(ancestor || resource, status.events)
  rescue => detail
    resource.err "Could not evaluate: #{detail}"
  end

  # Find all of the changed resources.
  def changed?
    report.resource_statuses.values.find_all { |status| status.changed }.collect { |status| catalog.resource(status.resource) }
  end

  # Find all of the applied resources (including failed attempts).
  def applied_resources
    report.resource_statuses.values.collect { |status| catalog.resource(status.resource) }
  end

  # Copy an important relationships from the parent to the newly-generated
  # child resource.
  def make_parent_child_relationship(parent, child)
    relationship_graph.add_vertex(child)
    edge = parent.depthfirst? ? [child, parent] : [parent, child]
    if relationship_graph.edge?(*edge.reverse)
      parent.debug "Skipping automatic relationship to #{child}"
    else
      relationship_graph.add_edge(*edge)
    end
  end

  # Evaluate a single resource.
  def eval_resource(resource, ancestor = nil)
    if skip?(resource)
      resource_status(resource).skipped = true
    else
      resource_status(resource).scheduled = true
      apply(resource, ancestor)
    end

    # Check to see if there are any events queued for this resource
    event_manager.process_events(resource)
  end

  # This method does all the actual work of running a transaction.  It
  # collects all of the changes, executes them, and responds to any
  # necessary events.
  def evaluate
    # Start logging.
    Puppet::Util::Log.newdestination(@report)

    prepare

    Puppet.info "Applying configuration version '#{catalog.version}'" if catalog.version

    begin
      relationship_graph.traverse do |resource|
        if resource.is_a?(Puppet::Type::Component)
          Puppet.warning "Somehow left a component in the relationship graph"
        else
          seconds = thinmark { eval_resource(resource) }
          resource.info "Evaluated in %0.2f seconds" % seconds if Puppet[:evaltrace] and @catalog.host_config?
        end
      end
    ensure
      # And then close the transaction log.
      Puppet::Util::Log.close(@report)
    end

    Puppet.debug "Finishing transaction #{object_id}"
  end

  def events
    event_manager.events
  end

  def failed?(resource)
    s = resource_status(resource) and s.failed?
  end

  # Does this resource have any failed dependencies?
  def failed_dependencies?(resource)
    # First make sure there are no failed dependencies.  To do this,
    # we check for failures in any of the vertexes above us.  It's not
    # enough to check the immediate dependencies, which is why we use
    # a tree from the reversed graph.
    found_failed = false
    relationship_graph.dependencies(resource).each do |dep|
      next unless failed?(dep)
      resource.notice "Dependency #{dep} has failures: #{resource_status(dep).failed}"
      found_failed = true
    end

    found_failed
  end

  def eval_generate(resource)
    return [] unless resource.respond_to?(:eval_generate)
    whit_class  = Puppet::Type.type(:whit)
    notify_clone = whit_class.new(:name => "notify_clone_#{resource.name}", :catalog => @catalog)
    print "resource I'm eval_generating on:"
    p resource
    relationship_graph.adjacent(resource, :direction => :out,:type => :edges).each { |e|
      print "edge i wanna maybe copy: "
      p e
      next unless e.label[:callback] == :refresh
      print "whit connects to: "
      p e.target
      print "this is a problem: "
      relationship_graph.add_edge( notify_clone, e.target, e.label )
    }
    begin
      made = resource.eval_generate
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      resource.err "Failed to generate additional resources using 'eval_generate: #{detail}"
    end
    parents = [resource]
    made = [made].flatten.compact.uniq
    made.each do |res|
      begin
        res.tag(*resource.tags)
        @catalog.add_resource(res)
        res.finish
        relationship_graph.add_edge( res, notify_clone, { :event => :ALL_EVENTS, :callback => :refresh } )
        make_parent_child_relationship(parents.reverse.find { |r| r.name == res.name[0,r.name.length]}, res)
        parents << res
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        res.info "Duplicate generated resource; skipping"
      end
    end
    return( made + [notify_clone] )
  rescue => e
    p e
    puts e.backtrace
    raise
  end

  # A general method for recursively generating new resources from a
  # resource.
  def generate_additional_resources(resource)
    return [] unless resource.respond_to?(:generate)
    begin
      made = resource.generate
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      resource.err "Failed to generate additional resources using 'generate': #{detail}"
    end
    return [] unless made
    made = [made] unless made.is_a?(Array)
    made.uniq.find_all do |res|
      begin
        res.tag(*resource.tags)
        @catalog.add_resource(res)
        res.finish
        make_parent_child_relationship(resource, res)
        generate_additional_resources(res)
        true
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        res.info "Duplicate generated resource; skipping"
        false
      end
    end
  end

  # Collect any dynamically generated resources.  This method is called
  # before the transaction starts.
  def generate
    list = @catalog.vertices
    newlist = []
    while ! list.empty?
      list.each do |resource|
        newlist += generate_additional_resources(resource)
      end
      list = newlist
      newlist = []
    end
  end

  # Should we ignore tags?
  def ignore_tags?
    ! (@catalog.host_config? or Puppet[:name] == "puppet")
  end

  # this should only be called by a Puppet::Type::Component resource now
  # and it should only receive an array
  def initialize(catalog)
    @catalog = catalog

    @report = Puppet::Transaction::Report.new("apply")

    @event_manager = Puppet::Transaction::EventManager.new(self)

    @resource_harness = Puppet::Transaction::ResourceHarness.new(self)
  end

  # Prefetch any providers that support it.  We don't support prefetching
  # types, just providers.
  def prefetch
    prefetchers = {}
    @catalog.vertices.each do |resource|
      if provider = resource.provider and provider.class.respond_to?(:prefetch)
        prefetchers[provider.class] ||= {}
        prefetchers[provider.class][resource.name] = resource
      end
    end

    # Now call prefetch, passing in the resources so that the provider instances can be replaced.
    prefetchers.each do |provider, resources|
      Puppet.debug "Prefetching #{provider.name} resources for #{provider.resource_type.name}"
      begin
        provider.prefetch(resources)
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Could not prefetch #{provider.resource_type.name} provider '#{provider.name}': #{detail}"
      end
    end
  end

  # Prepare to evaluate the resources in a transaction.
  def prepare
    # Now add any dynamically generated resources
    generate

    # Then prefetch.  It's important that we generate and then prefetch,
    # so that any generated resources also get prefetched.
    prefetch
  end


  # We want to monitor changes in the relationship graph of our
  # catalog but this is complicated by the fact that the catalog
  # both is_a graph and has_a graph, by the fact that changes to
  # the structure of the object can have adverse serialization
  # effects, by threading issues, by order-of-initialization issues,
  # etc.
  #
  # Since the proper lifetime/scope of the monitoring is a transaction
  # and the transaction is already commiting a mild law-of-demeter
  # transgression, we cut the Gordian knot here by simply wrapping the
  # transaction's view of the resource graph to capture and maintain
  # the information we need.  Nothing outside the transaction needs
  # this information, and nothing outside the transaction can see it
  # except via the Transaction#relationship_graph

  class Relationship_graph_wrapper
    attr_reader :real_graph,:transaction,:ready,:generated,:done,:unguessable_deterministic_key
    def initialize(real_graph,transaction)
      @real_graph = real_graph
      @transaction = transaction
      @ready = {}
      @generated = {}
      @done = {}
      @unguessable_deterministic_key = Hash.new { |h,k| h[k] = Digest::SHA1.hexdigest("NaCl, MgSO4 (salts) and then #{k.title}") }
      vertices.each { |v| check_if_now_ready(v) }
    end
    def method_missing(*args,&block)
      real_graph.send(*args,&block)
    end
    def add_vertex(v)
      real_graph.add_vertex(v)
      print "ADDING VERTEX TO READY "
      puts v.inspect
      ready[v] = true
    end
    def add_edge(f,t, *args)
      ready.delete(t)
      real_graph.add_edge(f,t, *args)
    end
    def check_if_now_ready(r)
      p [:check_if_now_ready, r]
      ready[r] = true if direct_dependencies_of(r).all? { |r2| done[r2] }
    end
    def next_resource
      ready.keys.sort_by { |r0| unguessable_deterministic_key[r0] }.first
    end
    def traverse(&block)
      while (r = next_resource).tap{|x| p x} && !transaction.stop_processing?
        print "TRAVERSE:"
        p r
        if !generated[r]
          transaction.eval_generate(r).each do |new_resource|
            p [:new_resource, new_resource]
            check_if_now_ready(new_resource)
          end
          generated[r] = true
        else
          ready.delete(r)
          yield r
          done[r] = true
          direct_dependents_of(r).each { |v| check_if_now_ready(v) }
        end
      end
    end
  end

  def relationship_graph
    @relationship_graph ||= Relationship_graph_wrapper.new(catalog.relationship_graph,self)
  end

  def add_resource_status(status)
    report.add_resource_status status
  end

  def resource_status(resource)
    report.resource_statuses[resource.to_s] || add_resource_status(Puppet::Resource::Status.new(resource))
  end

  # Is the resource currently scheduled?
  def scheduled?(resource)
    self.ignoreschedules or resource_harness.scheduled?(resource_status(resource), resource)
  end

  # Should this resource be skipped?
  def skip?(resource)
    if missing_tags?(resource)
      resource.debug "Not tagged with #{tags.join(", ")}"
    elsif ! scheduled?(resource)
      resource.debug "Not scheduled"
    elsif failed_dependencies?(resource)
      resource.warning "Skipping because of failed dependencies"
    elsif resource.virtual?
      resource.debug "Skipping because virtual"
    else
      return false
    end
    true
  end

  # The tags we should be checking.
  def tags
    self.tags = Puppet[:tags] unless defined?(@tags)

    super
  end

  def handle_qualified_tags( qualified )
    # The default behavior of Puppet::Util::Tagging is
    # to split qualified tags into parts. That would cause
    # qualified tags to match too broadly here.
    return
  end

  # Is this resource tagged appropriately?
  def missing_tags?(resource)
    return false if ignore_tags?
    return false if tags.empty?

    not resource.tagged?(*tags)
  end
end

require 'puppet/transaction/report'

