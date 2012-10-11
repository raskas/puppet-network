module Puppet

  newtype(:network_route) do

    @doc = "Manage the routing table entries"

    ensurable

    newparam(:name) do
      isnamevar
    end

    newproperty(:enable) do
      newvalues(:true, :false)
      defaultto(:false)
    end

    newproperty(:family) do
      newvalues(:inet, :inet6)
      defaultto(:inet)
    end

    newproperty(:via) do
      desc "the  address  of  the nexthop router."
    end

    newproperty(:to) do
      desc "the destination prefix of the route."
    end

    newproperty(:device) do
      desc "the output device name."
      defaultto('eth0')
    end

    newproperty(:table) do
      desc "the table to add this route to."
    end

    # Autorequire the interface
    autorequire(:network_interface) do
      self[:device]
    end

  end

end
