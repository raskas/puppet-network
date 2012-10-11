module Puppet

  newtype(:network_rule) do

    @doc = "Manage the routing policy database (RPDB)"

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

    newproperty(:from) do
      desc "the source prefix to match"
    end

    newproperty(:table) do
      desc "the routing table identifier to lookup if the rule selector matches"
    end

    newproperty(:fwmark) do
      desc "select the fwmark value to match"
    end

#    newproperty(:priority) do
#      desc "the priority of this rule"
#    end

    newproperty(:device) do
      defaultto('eth0')
    end

  end

end
