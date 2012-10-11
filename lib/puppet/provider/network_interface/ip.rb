Puppet::Type.type(:network_interface).provide(:ip) do

  # ip command is preferred over ifconfig
  commands :ip => "/sbin/ip", :vconfig => "/sbin/vconfig", :echo => "/bin/echo", :modprobe => "/sbin/modprobe", :ifenslave => "/sbin/ifenslave"

  # Uses the ip command to determine if the device exists
  def exists?
#    ip('link', 'list', @resource[:name])
    ip('addr', 'show', 'label', @resource[:device]).include?("inet") || ip('addr', 'show', 'label', @resource[:device]).include?("SLAVE")
  rescue Puppet::ExecutionFailure
    return false
#     raise Puppet::Error, "Network interface %s does not exist" % @resource[:name] 
  end 

  def create
    if @resource[:device].index('bond0')
      File.open("/etc/modprobe.d/bonding.conf", 'w') do |f|
        f.write("alias bond0 bonding\n")
        f.write("options bonding mode=1 miimon=100 primary=eth0 updelay=120000\n")
      end
      modprobe('bonding')
    end
    if @resource[:vlan] == :yes 
      # Supporting hierarchical VLANs (QinQ)
      vlans = @resource[:device].split(':').first.split('.')
      iface = vlans.shift 
      # Recursively create and bring up VLAN devices
      vlans.each do |vlan| 
        if ! ip('link', 'list').include?(iface+'.'+vlan+'@')
          vconfig('add', iface, vlan)
        end
        iface = iface.concat('.').concat(vlan)
        ip('link','set','up','dev', iface)
      end 
    end
    unless @resource.should(:ipaddr).nil? || @resource.should(:netmask).nil? || self.netmask == @resource.should(:netmask) || self.ipaddr == @resource.should(:ipaddr)
      ip_addr_flush
      ip_addr_add
    end
    unless @resource.should(:ipv6addr).nil? || self.ipv6addr == @resource.should(:ipv6addr)
      ipv6_addr_update
    end
    unless @resource.should(:mtu).nil? || self.mtu == @resource.should(:mtu)
      self.mtu=(@resource.should(:mtu))
    end
    unless @resource.should(:master).nil? || self.master == @resource.should(:master)
      self.master=(@resource.should(:master))
    end
    unless @resource.should(:state).nil? || self.state == @resource.should(:state)
      self.state=(@resource.should(:state))
    end
  end

  def destroy
    ip_addr_flush
    if @resource[:vlan] == :yes
      # Supporting hierarchical VLANs (QinQ)
      vlans = @resource[:device].split(':').first.split('.')
      iface = vlans.shift
      # Recursively remove VLAN devices
      while vlans.length > 0 
        # Test if no hierarchical VLANs are configured on this vlan device
        if ! ip('link', 'list').include?(iface+'.'+vlans.join('.')+'.')
          # Test if no scope global ip addresses are configured on this vlan device
          if ! ip('addr', 'show', iface+'.'+vlans.join('.')).include?("scope global")
            # Destroy vlan device
            vconfig('rem', iface+'.'+vlans.join('.'))
          else
            break
          end
        else
          break
        end
        vlans.pop
      end
    end
    if @resource[:device].index('bond0')
      File.unlink('/etc/modprobe.d/bonding.conf')
      modprobe('-r', 'bonding')
    end
  end

 # MASTER
  def master
    lines = ip('addr', 'show', 'label', @resource[:device])
    lines.scan(/ master (.*?) /)
    $1.nil? ? :absent : $1
  end

  def master=(value)
    if self.master != :absent
      ifenslave('-d', self.master, @resource[:device])
    end
    ifenslave(@resource[:master], @resource[:device])
  end

 # NETMASK
  def netmask
    lines = ip('addr', 'show', 'label', @resource[:device])
    lines.scan(/\s*inet (\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)\/(\d+) b?r?d?\s*(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)?\s*scope (\w+) (\w+:?\d*)/)
    $2.nil? ? :absent : $2
  end

  def netmask=(value)
    ip_addr_flush
    ip_addr_add
  end

 # IPADDR
  def ipaddr
    lines = ip('addr', 'show', 'label', @resource[:device])
    lines.scan(/\s*inet (\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)\/(\d+) b?r?d?\s*(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)?\s*scope (\w+) (\w+:?\d*)/)
    $1.nil? ? :absent : $1
  end

  def ipaddr=(value)
    ip_addr_flush
    ip_addr_add
  end

 # IPV6ADDR
  def ipv6addr
    lines = ip('addr', 'show', 'label', @resource[:device])
    mac=lines.scan(/\s*link\/ether\s*((?:[a-f0-9][a-f0-9]:){5}[a-f0-9][a-f0-9]).*/).to_s.split(':')
    if ! mac.empty?
      linkaddr="fe80::" + ((mac[0].hex.to_i^2).to_s(16) + mac[1]).gsub(/^0*/,"") + ":" + mac[2].gsub(/^0*/,"") + "ff:fe" + mac[3] + ":" + (mac[4].hex.to_i.to_s(16) + mac[5]).gsub(/^0*/,"") + "/64"
    end
    ipv6addresses=lines.scan(/\s*inet6 ([a-f0-9:]+\/\d+)\s*scope.*/).flatten
    if ! linkaddr.nil?
      unless ipv6addresses.nil? 
        ipv6addresses.delete(linkaddr)
      end
    end
    ipv6addresses.nil? ? :absent : ipv6addresses.sort.join(' ')
  end

  def ipv6addr=(value)
    ipv6_addr_update
  end

 # MTU
  def mtu
    lines = ip('link', 'show', 'dev', @resource[:device])
    lines.scan(/.* mtu (\d+) /)
    $1.nil? ? :absent : $1
  end

  def mtu=(value)
    ip('link', 'set', 'dev', @resource[:device], 'mtu', value)
  end

  
  def ip_addr_flush
    ip('-4','addr', 'flush', 'dev', @resource[:device], 'label', @resource[:device].sub(/:/, '\:'))
  end

  def ip_addr_add
    ip('addr', 'add', @resource[:ipaddr] + "/" + @resource[:netmask], 'broadcast', '+', 'label', @resource[:device], 'dev', @resource[:device])
  end

  def ipv6_addr_update
    lines = ip('addr', 'show', 'label', @resource[:device])
    mac=lines.scan(/\s*link\/ether\s*((?:[a-f0-9][a-f0-9]:){5}[a-f0-9][a-f0-9]).*/).to_s.split(':')
    if ! mac.empty?
      linkaddr="fe80::" + ((mac[0].hex.to_i^2).to_s(16) + mac[1]).gsub(/^0*/,"") + ":" + mac[2].gsub(/^0*/,"") + "ff:fe" + mac[3] + ":" + (mac[4].hex.to_i.to_s(16) + mac[5]).gsub(/^0*/,"") + "/64"
    end

    lines = ip('addr', 'show', 'label', @resource[:device])
    ipv6addr_present=lines.scan(/\s*inet6 ([a-f0-9:]+\/\d+)\s*scope.*/).flatten
    ipv6addr_expected=@resource[:ipv6addr].split(/\s+/)
    if ! linkaddr.nil? 
      ipv6addr_expected.push(linkaddr)
    end

    ipv6addr_add=Array.new(ipv6addr_expected)
    ipv6addr_del=[]

    ipv6addr_present.each do |addr|
      if ipv6addr_expected.include?(addr)
        ipv6addr_add.delete(addr)
      else
        ipv6addr_del.push(addr)
      end
    end

    unless ipv6addr_del.empty?
      ipv6addr_del.each do |addr|
        ip('addr', 'del', addr, 'dev', @resource[:device])
      end
    end
    unless ipv6addr_add.empty?
      ipv6addr_add.each do |addr|
        ip('addr', 'add', addr, 'dev', @resource[:device])
      end
    end
  end

  def device
    config_values[:dev]
  end
  
  # Ensurable/ensure adds unnecessary complexity to this provider
  # Network interfaces are up or down, present/absent are unnecessary
  def state
    # When the resource is set to ':ignore', we always return :ignore
    if @resource.should(:state) == :ignore
      return :ignore
    end
    lines = ip('link', 'list', @resource[:name])
    if lines.include?("UP")
      return "up"
    else
      return "down"
    end 
  end

  # Set the interface's state
  # FIXME Facter bug #2211 prevents puppet from bringing up network devices
  def state=(value)
    if value != :ignore
      ip('link', 'set', 'dev', @resource[:name], value)
    end
  end

  # Current state of the device via the ip command
  def state_values
    @values ||= read_ip_output
  end

  # Return the ip output of the device
  def ip_output
    ip('addr','show', 'dev', @resource[:name])
  end

  # FIXME Back Named Reference Captures are supported in Ruby 1.9.x
  def read_ip_output
    output = ip_output
    lines = output.split("\n")
    line1 = lines.shift
    line2 = lines.shift
    i=0
    j=0
    p=0
   
    # Append ipv6 lines into one string
    lines.each do |line|
      if line.include?("inet6")
        lines[p] = lines[p] + lines[p+1]
        lines.delete_at(p+1)
      else
        # move along, nothing to see here
      end
       p += 1 
    end

    #FIXME This should capture 'NOARP' and 'MULTICAST'
    # Scan the first line of the ip command output
    line1.scan(/\d: (\w+): <(\w+),(\w+),(\w+),?(\w*)> mtu (\d+) qdisc (\w+) state (\w+)\s*\w* (\d+)*/)
    puts $1
    values = {  
      "device"    => $1,
      "mtu"       => $6,
      "qdisc"     => $7,
      "state"     => $8,
      "qlen"      => $9, 
    }
    line1.scan(/^\d+: (.+): <(\w+),(\w+),(\w+),?(\w*)> mtu (\d+) qdisc (\w+) (state (\w+)\s*\w* (\d+)*)?/)
    puts $6
    values = {  
      "device"    => $1,
      "mtu"       => $6,
      "qdisc"     => $7,
    }
    
    # Scan the second line of the ip command output
    line2.scan(/\s*link\/\w+ ((?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}) brd ((?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})/) 
    values["address"]   = $1
    values["broadcast"] = $2 
   
    # Scan all the inet and inet6 entries
    lines.each do |line|
      if line.include?("inet6") 
        line.scan(/\s*inet6 ((?>[0-9,a-f,A-F]*\:{1,2})+[0-9,a-f,A-F]{0,4})\/\w+ scope (\w+)\s*\w*\s*valid_lft (\w+) preferred_lft (\w+)/)
        values["inet6_#{j}"] = { 
          "ip"              => $1,
          "scope"           => $2, 
          "valid_lft"       => $3,
          "preferred_lft"   => $4, 
        }
        j += 1
      else
        line.scan(/\s*inet (\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)\/\d+ b?r?d?\s*(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)?\s*scope (\w+) (\w+:?\d*)/)
        values["inet_#{i}"] = { 
          "ip"         => $1,
          "brd"        => $2,
          "scope"      => $3,
          "dev"        => $4, 
        }
        i += 1
      end
    end
    
  return values

  end

  #FIXME Need to support multiple inet & inet6 hashes
  IP_ARGS = [ "qlen", "address" ]

  IP_ARGS.each do |ip_arg|
    define_method(ip_arg.to_s.downcase) do
      state_values[ip_arg]
    end
    
    define_method("#{ip_arg}=".downcase) do |value|
      ip('link', 'set', "#{ip_arg}", value, 'dev', @resource[:name])
      state_values[ip_arg] = value
    end
  end
  
end
