require 'puppet/resource/status'

class Puppet::Transaction::ResourceHarness
  extend Forwardable
  def_delegators :@transaction, :relationship_graph

  attr_reader :transaction

  def allow_changes?(resource)
    return true unless resource.purging? and resource.deleting?
    return true unless deps = relationship_graph.dependents(resource) and ! deps.empty? and deps.detect { |d| ! d.deleting? }

    deplabel = deps.collect { |r| r.ref }.join(",")
    plurality = deps.length > 1 ? "":"s"
    resource.warning "#{deplabel} still depend#{plurality} on me -- not purging"
    false
  end

  # Used mostly for scheduling and auditing at this point.
  def cached(resource, name)
    Puppet::Util::Storage.cache(resource)[name]
  end

  # Used mostly for scheduling and auditing at this point.
  def cache(resource, name, value)
    Puppet::Util::Storage.cache(resource)[name] = value
  end

  def perform_changes(status, resource)
    current = resource.retrieve_resource

    cache resource, :checked, Time.now

    return if ! allow_changes?(resource)

    audited = copy_audited_parameters(resource, current)

    if param = resource.parameter(:ensure)
      return if absent_and_not_being_created?(current, param)
      unless ensure_is_insync?(current, param)
        audited.keys.reject{|name| name == :ensure}.each do |name|
          cache(resource, name, current[param])
          event = create_change_event(resource.parameter(name), current[name], true, audited[name])
          status << event
          event.send_log
        end
        status << apply_change(param, current[:ensure], audited.include?(:ensure), audited[:ensure])
        return
      end
      return if ensure_should_be_absent?(current, param)
    end

    resource.properties.reject { |param| param.name == :ensure }.select do |param|
      (audited.include?(param.name) && audited[param.name] != current[param.name]) || (param.should != nil && !param_is_insync?(current, param))
    end.each do |param|
      if audited.include?(param.name)
        cache(param.resource, param.name, current[param.name])
      end

      status << apply_change(param, current[param.name], audited.include?(param.name), audited[param.name])
    end
  end

  def create_change_event(property, current_value, do_audit, historical_value)
    event = property.event
    event.previous_value = current_value
    event.desired_value = property.should
    event.historical_value = historical_value

    if do_audit and historical_value != current_value
      event.message = "audit change: previously recorded value #{property.is_to_s(historical_value)} has been changed to #{property.is_to_s(current_value)}"
      event.status = "audit"
      event.audited = true
    end

    event
  end

  def apply_change(property, current_value, do_audit, historical_value)
    event = create_change_event(property, current_value, do_audit, historical_value)

    if event.audited
      brief_audit_message = " (previously recorded value was #{property.is_to_s(historical_value)})" 
    else
      brief_audit_message = "" 
    end

    if property.insync?(current_value)
      # nothing happens
    elsif property.noop
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

  def copy_audited_parameters(resource, current)
    return {} unless audit = resource[:audit]
    audit = Array(audit).collect { |p| p.to_sym }
    audited = {}
    audit.find_all do |param|
      if value = cached(resource, param)
        audited[param] = value
      else
        resource.property(param).notice "audit change: newly-recorded value #{current[param]}"
        cache(resource, param, current[param])
      end
    end

    audited
  end

  def evaluate(resource)
    start = Time.now
    status = Puppet::Resource::Status.new(resource)

    perform_changes(status, resource)

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

  def initialize(transaction)
    @transaction = transaction
  end

  def scheduled?(status, resource)
    return true if Puppet[:ignoreschedules]
    return true unless schedule = schedule(resource)

    # We use 'checked' here instead of 'synced' because otherwise we'll
    # end up checking most resources most times, because they will generally
    # have been synced a long time ago (e.g., a file only gets updated
    # once a month on the server and its schedule is daily; the last sync time
    # will have been a month ago, so we'd end up checking every run).
    schedule.match?(cached(resource, :checked).to_i)
  end

  def schedule(resource)
    unless resource.catalog
      resource.warning "Cannot schedule without a schedule-containing catalog"
      return nil
    end

    return nil unless name = resource[:schedule]
    resource.catalog.resource(:schedule, name) || resource.fail("Could not find schedule #{name}")
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
