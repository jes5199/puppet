require 'puppet/transaction'
require 'puppet/transaction/event'

# Handle all of the work around performing an actual change,
# including calling 'sync' on the properties and producing events.
class Puppet::Transaction::Change
  attr_accessor :is, :should, :property, :proxy, :auditing, :old_audit_value

  def auditing?
    auditing
  end

  def initialize(property, currentvalue)
    @property = property
    @is = currentvalue

    @should = property.should

    @changed = false
  end

  def apply
    result = property.event
    result.previous_value = is
    result.desired_value = should

    result.historical_value = old_audit_value

    if auditing? and old_audit_value != is
      result.message = "audit change: previously recorded value #{property.is_to_s(old_audit_value)} has been changed to #{property.is_to_s(is)}"
      result.status = "audit"
      result.send_log
    end
    return result if property.insync?(is)

    if noop?
      result.message = "is #{property.is_to_s(is)}, should be #{property.should_to_s(should)} (noop)"
      result.status = "noop"
      result.send_log
      return result
    end

    property.sync

    result.message = property.change_to_s(is, should)
    result.status = "success"
    result.send_log
    result
  rescue => detail
    puts detail.backtrace if Puppet[:trace]
    result.status = "failure"

    result.message = "change from #{property.is_to_s(is)} to #{property.should_to_s(should)} failed: #{detail}"
    result.send_log
    result
  end

  # Is our property noop?  This is used for generating special events.
  def noop?
    @property.noop
  end

  # The resource that generated this change.  This is used for handling events,
  # and the proxy resource is used for generated resources, since we can't
  # send an event to a resource we don't have a direct relationship with.  If we
  # have a proxy resource, then the events will be considered to be from
  # that resource, rather than us, so the graph resolution will still work.
  def resource
    self.proxy || @property.resource
  end

  def to_s
    "change #{@property.change_to_s(@is, @should)}"
  end
end
