module Puppet

  newtype(:network_bridge) do

    @doc = "Manage bridges"

    ensurable

    newparam(:name) do
      isnamevar
    end

    newproperty(:interfaces, :array_matching => :all) do
      desc "Configure interfaces connected to the bridge"
    end

    newproperty(:delay) do
      desc "Configure bridge forward delay"
      munge do |value|
        "%.2f" % value
      end
    end

  end

end
