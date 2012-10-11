Puppet::Type.type(:network_bridge).provide(:brctl) do

  commands :brctl => "/usr/sbin/brctl"

  def exists?

    @@config = load_bridge_info
    if @@config[@resource[:name]].nil?
      return false
    else
      return true
    end

  end

  def create

    brctl('addbr', @resource[:name])

    unless @resource.should(:delay).nil? || self.delay == @resource.should(:delay)
      self.delay=(@resource.should(:delay))
    end

    add_interface_to_bridge(@resource[:name], @resource[:interfaces])

  end

  def destroy

    brctl('delbr', @resource[:name])

  end

  # Getters and Setters
  #####
  
  def interfaces
    @@config[@resource[:name]]['interfaces']
  end

  def interfaces=(value)

    # interfaces that needs to be deleted
    tb_del = self.interfaces - @resource[:interfaces]
    del_interface_from_bridge(@resource[:name], tb_del)

    # interfaces that needs to be created
    tb_add = @resource[:interfaces] - self.interfaces
    add_interface_to_bridge(@resource[:name], tb_add)

  end

  def delay
    brctl('showstp',@resource[:name]).split("\n").each do |line|
      if ( line =~ /^\s*forward delay\s*(\d+\.\d\d)\s+/ ) 
        return "%.2f" % ( 0.00 ) if ( $1 == "0.00" )
        return "%.2f" % ( $1.to_f + 0.01 )
      end
    end
  end

  def delay=(value)
    brctl('setfd',@resource[:name],value)
  end

  # Helper functions
  #####

  # run "brctl show" and store all info in a hash
  def load_bridge_info

    config    = Hash.new
    bridge    = nil
    interface = nil

    brctl('show').split("\n").each do |line|

      # skip header
      next if line.include?('bridge name')

      line.scan(/^(.*?)\s+(.*?)\s+(.*?)\s+(.*)$/)

      # get bridge, keep previous entry if it is empty
      if ! $1.empty? 
        # new bridge defined
        bridge = $1
        config[bridge] = Hash.new
        config[bridge]['interfaces'] = Array.new
      end

      # get interfaces
      if ! $4.empty?
        # interface defined
        config[bridge]['interfaces'] << $4
      end

    end

    return config

  end

  def add_interface_to_bridge ( bridge, interfaces )

    interfaces.each do |interface|

      brctl('addif', bridge, interface)

    end

  end

  def del_interface_from_bridge ( bridge, interfaces )

    interfaces.each do |interface|

      brctl('delif', bridge, interface)

    end

  end

end
