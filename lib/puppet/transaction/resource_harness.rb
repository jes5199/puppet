require 'puppet/resource/status'

class Puppet::Transaction::ResourceHarness
  def perform_changes(relationship_graph, resource)
    current = resource.retrieve_resource

    Puppet::Util::Storage.persistent_state_for(resource)[:checked] = Time.now

    return [] if ! resource.allow_changes?(relationship_graph)

    current_values = current.to_hash
    historical_values = Puppet::Util::Storage.persistent_state_for(resource).dup
    desired_values = resource.to_resource.to_hash
    audited_params = (resource[:audit] || []).map { |p| p.to_sym }
    synced_params = []

    # Record the current state in state.yml.
    audited_params.each do |param|
      Puppet::Util::Storage.persistent_state_for(resource)[param] = current_values[param]
    end

    # Update the machine state & create logs/events
    events = []
    ensure_param = resource.parameter(:ensure)
    if desired_values[:ensure] && !ensure_param.insync?(current_values[:ensure])
      events << ensure_param.apply_parameter(current_values[:ensure], audited_params.include?(:ensure), historical_values[:ensure])
      synced_params << :ensure
    elsif current_values[:ensure] != :absent
      work_order = resource.properties # Note: only the resource knows what order to apply changes in
      work_order.each do |param|
        if !param.insync?(current_values[param.name])
          events << param.apply_parameter(current_values[param.name], audited_params.include?(param.name), historical_values[param.name])
          synced_params << param.name
        end
      end
    end

    # Add more events to capture audit results
    audited_params.each do |param_name|
      if historical_values.include?(param_name)
        if historical_values[param_name] != current_values[param_name] && !synced_params.include?(param_name)
          event = resource.parameter(param_name).create_change_event(current_values[param_name], true, historical_values[param_name])
          event.send_log
          events << event
        end
      else
        resource.property(param_name).notice "audit change: newly-recorded value #{current_values[param_name]}"
      end
    end

    events
  end

  def evaluate(relationship_graph, resource)
    start = Time.now
    status = Puppet::Resource::Status.new(resource)

    perform_changes(relationship_graph, resource).each do |event|
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
