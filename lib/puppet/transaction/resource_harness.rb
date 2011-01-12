require 'puppet/resource/status'

class Puppet::Transaction::ResourceHarness
  def evaluate(relationship_graph, resource)
    start = Time.now
    status = Puppet::Resource::Status.new(resource)

    resource.perform_changes(relationship_graph).each do |event|
      status << event
    end

    if status.changed? && ! resource.noop?
      Puppet::Util::Cache.persistent_state_for(resource)[:synced] = Time.now
      resource.flush if resource.respond_to?(:flush)
    end

    return status
  rescue => detail
    resource.fail "Could not create resource status: #{detail}" unless status
    puts detail.backtrace if Puppet[:trace]
    resource.err "Could not evaluate: #{detail}"
    status.failed = true
    return status
  ensure
    (status.evaluation_time = Time.now - start) if status
  end

end
