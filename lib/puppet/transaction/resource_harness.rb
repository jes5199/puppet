require 'puppet/resource/status'

class Puppet::Transaction::ResourceHarness
  def perform_changes(relationship_graph, resource)
    current = resource.retrieve_resource

    Puppet::Util::Storage.cache(resource)[:checked] = Time.now

    return [] if ! resource.allow_changes?(relationship_graph)

    current_values = current.to_hash
    historical_values = Puppet::Util::Storage.cache(resource).dup
    desired_values = resource.to_resource.to_hash
    audited_params = (resource[:audit] || []).map { |p| p.to_sym }
    synced_params = []

    # Record the current state in state.yml.
    audited_params.each do |param|
      Puppet::Util::Storage.cache(resource)[param] = current_values[param]
    end

    # Update the machine state & create logs/events
    events = []
    ensure_param = resource.parameter(:ensure)
    if desired_values[:ensure] && !ensure_param.insync?(current_values[:ensure])
      events << apply_parameter(ensure_param, current_values[:ensure], audited_params.include?(:ensure), historical_values[:ensure])
      synced_params << :ensure
    elsif current_values[:ensure] != :absent
      work_order = resource.properties # Note: only the resource knows what order to apply changes in
      work_order.each do |param|
        if !param.insync?(current_values[param.name])
          events << apply_parameter(param, current_values[param.name], audited_params.include?(param.name), historical_values[param.name])
          synced_params << param.name
        end
      end
    end

    # Add more events to capture audit results
    audited_params.each do |param_name|
      if historical_values.include?(param_name)
        if historical_values[param_name] != current_values[param_name] && !synced_params.include?(param_name)
          event = create_change_event(resource.parameter(param_name), current_values[param_name], true, historical_values[param_name])
          event.send_log
          events << event
        end
      else
        resource.property(param_name).notice "audit change: newly-recorded value #{current_values[param_name]}"
      end
    end

    events
  end

  def create_change_event(property, current_value, do_audit, historical_value)
    event = property.event
    event.previous_value = current_value
    event.desired_value = property.should
    event.historical_value = historical_value

    if do_audit
      event.audited = true
      event.status = "audit"
      if historical_value != current_value
        event.message = "audit change: previously recorded value #{property.is_to_s(historical_value)} has been changed to #{property.is_to_s(current_value)}"
      end
    end

    event
  end

  def apply_parameter(property, current_value, do_audit, historical_value)
    event = create_change_event(property, current_value, do_audit, historical_value)

    if do_audit && historical_value && historical_value != current_value
      brief_audit_message = " (previously recorded value was #{property.is_to_s(historical_value)})"
    else
      brief_audit_message = ""
    end

    if property.noop
      event.message = "current_value #{property.is_to_s(current_value)}, should be #{property.should_to_s(property.should)} (noop)#{brief_audit_message}"
      event.status = "noop"
    else
      property.sync
      event.message = [ property.change_to_s(current_value, property.should), brief_audit_message ].join
      event.status = "success"
    end
    event
  rescue => detail
    puts detail.backtrace if Puppet[:trace]
    event.status = "failure"

    event.message = "change from #{property.is_to_s(current_value)} to #{property.should_to_s(property.should)} failed: #{detail}"
    event
  ensure
    event.send_log
  end

  def evaluate(relationship_graph, resource)
    start = Time.now
    status = Puppet::Resource::Status.new(resource)

    perform_changes(relationship_graph, resource).each do |event|
      status << event
    end

    if status.changed? && ! resource.noop?
      cache(resource, :synced, Time.now)
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

  private

  def absent_and_not_being_created?(current, param)
    current[:ensure] == :absent and param.should.nil?
  end

  def ensure_is_insync?(current, param)
    param.insync?(current[:ensure])
  end

  def ensure_should_be_absent?(current, param)
    param.should == :absent
  end

  def param_is_insync?(current, param)
    param.insync?(current[param.name])
  end
end
