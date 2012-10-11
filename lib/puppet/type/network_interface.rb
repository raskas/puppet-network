require 'puppet'
require 'ipaddr'

module Puppet

  Puppet::Type.newtype(:network_interface) do
    @doc = "The network managment configuration type"

    ensurable

    newparam(:device) do
      isnamevar
      desc "The network device to be configured"
    end

    newproperty(:state) do
      desc "state of the interface"
      newvalues(:up, :down, :ignore)
      defaultto(:up)
    end

    newproperty(:inet) do
      desc "Configure the IPV4 address of the device"
    end

    newproperty(:inet6) do
      desc "Configure the IPV6 address of the device"
    end

    newproperty(:gateway) do
      desc "Configure the Gateway of the device"
    end

    newproperty(:address) do
      desc "Hardware address of the device"
    end

    newproperty(:arp) do
       desc "Arp"
       newvalues(:on, :off)
    end

    newproperty(:multicast) do
      desc "multicast"
      newvalues(:on, :off)
    end

    newproperty(:dynamic) do
      desc "dynamic"
      newvalues(:on, :off)
    end

    newproperty(:qlen) do
      desc "txquelen"
    end

    newproperty(:mtu) do
      desc "mtu"
    end

    newparam(:vlan) do
      desc "Is the device VLAN tagged (802.1q)"
      newvalues(:yes, :no)
      defaultto(:no)
    end

    newproperty(:ipaddr) do
      desc "Configure the IP address of the device"
    end

    newproperty(:ipv6addr) do
      desc "Configure the IPv6 addresses of the device as space seperated string"

      munge do |value|
        value.downcase
      end
    end

    newproperty(:netmask) do
      desc "Configure the subnetmask of the device"

      munge do |value|
        if value.match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
          IPAddr.new(value).to_i.to_s(2).count("1").to_s
        else
          super
        end
      end
    end

    newproperty(:master) do
      desc "This is needed on a slave interface to point to the master"
    end

    # Autorequire the parent interface
    autorequire(:network_interface) do
      reqs = []

      # Check if it is an alias interface (contains ':')
      if self[:device] =~ /\:/
        # Strip the alias entry of the devicename
        reqs << self[:device][0,self[:device].rindex(':')]
      # Check if it is a vlan interface (contains '.')
      elsif self[:device] =~ /\./
        # Strip the last vlan entry of the devicename
        reqs << self[:device][0,self[:device].rindex('.')]
      end

      # Check if it is slave interfaces (master is defined)
      if self[:master]
        reqs << self[:master]
      end

      reqs
    end

  end
end
