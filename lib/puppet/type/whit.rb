Puppet::Type.newtype(:whit) do
  desc "The smallest possible resource type, for when you need a resource and naught else."

# feature :refreshable, "The provider can restart the service.",
#   :methods => [:refresh]

  newparam :name do
    desc "The name of the whit, because it must have one."
  end

  def to_s
    "Class[#{name}]"
  end

  # probably want to rename Whit now that it has behavior. ~JW
  def refresh
    p [:refresh, name]
  end
end
