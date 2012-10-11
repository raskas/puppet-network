Puppet::Type.type(:network_rule).provide(:network_scripts) do

  commands :ip => "/sbin/ip"
  defaultfor :operatingsystem => [:redhat, :fedora, :centos]

  @@config_dir = '/etc/sysconfig/network-scripts/'
  @@default_inet_target  = 'rule-eth0'
  @@default_inet6_target = 'rule6-eth0'

  def exists?

    @@config = load_on_disk_configuration
    if @@config[@resource[:name]].nil?
      return false
    else
      return true
    end

  end

  def create

    create_resource

  end

  def destroy

    delete_resource

  end


  # Getters and Setters
  #####

  def enable

    # Count the occurences of the rule
    count = 0
    ip('-family', self.family, 'rule', 'show').each do |ip|
      count += 1 if ip =~ /#{ip_output_from_file}/
    end

    if count > 0
      :true
    else
      :false
    end

  end

  def enable=(value)
    if value == :true
      create_system_resource
    else
      delete_system_resource
    end
  end

  def family
    @@config[@resource[:name]]['family']
  end

  def family=(value)
    delete_resource
    create_resource
  end

  def from
    @@config[@resource[:name]]['from']
  end

  def from=(value)
    delete_resource
    create_resource
  end

  def fwmark
    @@config[@resource[:name]]['fwmark']
  end

  def fwmark=(value)
    delete_resource
    create_resource
  end

  def table
    @@config[@resource[:name]]['table']
  end

  def table=(value)
    delete_resource
    create_resource
  end

  def device
    @@config[@resource[:name]]['device']
  end

  def device=(value)
    # Only the file is modified as the device has no impact on the rule
    delete_file_resource
    create_file_resource
  end


  # Helper functions
  #####

  def load_on_disk_configuration
    config = Hash.new
    Dir.glob(@@config_dir + 'rule{6,}-*').each do |file|
      File.open(file, 'r') do |f|
        f.each do |line|
          line_arr = line.split()

          # search name
          if line_arr.index('#').nil?
            name = nil
          else
            name = line_arr[line_arr.index('#').to_i+1]
          end
          config[name] = Hash.new

          # search from
          if line_arr.index('from').nil?
            config[name]['from'] = nil
          else
            config[name]['from'] = line_arr[line_arr.index('from').to_i+1]
          end

          # search fwmark
          if line_arr.index('fwmark').nil?
            config[name]['fwmark'] = nil
          else
            config[name]['fwmark'] = line_arr[line_arr.index('fwmark').to_i+1]
          end

          # search table
          if line_arr.index('table').nil?
            config[name]['table'] = nil
          else
            config[name]['table'] = line_arr[line_arr.index('table').to_i+1]
          end

          # file
          config[name]['file'] = file

          # family
          if /rule6-/.match(config[name]['file']) 
            config[name]['family'] = 'inet6'
          else
            config[name]['family'] = 'inet'
          end

          # device
          config[name]['device'] = config[name]['file'].scan(/rule6?-(.*)$/).to_s

        end
      end
    end

    return config
  end

  # Build the 'ip rule add/del' command based on information received from the file
  def ip_cmd_from_file

    ip_cmd = ''
    ip_cmd += 'from '   + self.from   + ' ' if ! self.from.nil?   && ! self.from.empty?
    ip_cmd += 'fwmark ' + self.fwmark + ' ' if ! self.fwmark.nil? && ! self.fwmark.empty?
    ip_cmd += 'table '  + self.table  + ' ' if ! self.table.nil?  && ! self.table.empty?
    return ip_cmd

  end

  # Build the 'ip rule add/del' command based on information received from the resource
  def ip_cmd_from_should

    ip_cmd = ''
    ip_cmd += 'from '   + @resource.should(:from)   + ' ' if @resource.should(:from)
    ip_cmd += 'fwmark ' + @resource.should(:fwmark) + ' ' if @resource.should(:fwmark)
    ip_cmd += 'table '  + @resource.should(:table)  + ' ' if @resource.should(:table)
    return ip_cmd

  end

  # Build a regex which will match the 'ip rule show' output based on information received from the file
  def ip_output_from_file

    ip_output = '^\d+:\s+'
    ip_output += 'from '   + self.from + ' '                        if ! self.from.nil?   && ! self.from.empty?
    ip_output += 'from '   + 'all'     + ' '                        if   self.from.nil?   ||   self.from.empty?
    ip_output += 'fwmark ' + '0x' + self.fwmark.to_i.to_s(16) + ' ' if ! self.fwmark.nil? && ! self.fwmark.empty?
    ip_output += 'lookup ' + self.table                             if ! self.table.nil?  && ! self.table.empty?
    return ip_output

  end

  # Build a regex which will match the 'ip rule show' output based on information from the resource
  def ip_output_from_should

    ip_output = '^\d+:\s+'
    ip_output += 'from '   + @resource.should(:from)   + ' ' if @resource.should(:from)
    ip_output += 'from '   + 'all'              + ' ' if ! @resource.should(:from)
    ip_output += 'fwmark ' + '0x' + @resource.should(:fwmark).to_i.to_s(16) + ' ' if @resource.should(:fwmark)
    ip_output += 'lookup ' + @resource.should(:table)  if @resource.should(:table)
    return ip_output

  end


  # DELETE
  #########

  def delete_resource

    if @resource[:enable]
      delete_system_resource
    end
    delete_file_resource

  end

  def delete_file_resource

    # Read file to array
    line_arr = File.readlines(@@config[@resource[:name]]['file'])

    # Remove specific line from array
    line_arr.delete_if { |x| /# #{@resource[:name]}$/.match(x) }

    if line_arr.length == 0
      # Array is empty, we can remove the file
      File.unlink(@@config[@resource[:name]]['file'])
    else
      # Write array to file
      File.open(@@config[@resource[:name]]['file'], 'w') do |f|
        line_arr.each{ |line| f.puts(line) }
      end
    end

  end

  def delete_system_resource

    # Count the occurences of the rule
    count = 0
    ip('-family', self.family, 'rule', 'show').each do |ip|
      count += 1 if ip =~ /#{ip_output_from_file}/
    end

    # Delete every occurence of the rule
    if count > 0
      ip('-family', self.family, 'rule', 'del', ip_cmd_from_file.split(' '))
    end
      
  end


  # CREATE
  #########

  def create_resource

    create_file_resource
    if @resource[:enable]
      create_system_resource
    end

  end

  def create_file_resource

    # BUG: This function does not verify if the line is already present.
    # When eg. both the family and device are modified the same line
    # appears 2 times in the file, which isn't good.

    target = @@config_dir

    if @resource.should(:family) == :inet
      target += 'rule-'
    else
      target += 'rule6-'
    end
    target += @resource.should(:device)

    # Append the 'ip_cmd_from_should' string to the target file
    File.open(target, 'a+') { |f| f.write(ip_cmd_from_should + '# ' + @resource[:name] + "\n") }

  end

  def create_system_resource

    # Count the occurences of the rule
    count = 0
    ip('-family', @resource.should(:family), 'rule', 'show').each do |ip|
      count += 1 if ip =~ /#{ip_output_from_should}/
    end

    # Add the rule if it wasn't found
    if count == 0
      ip('-family', @resource.should(:family), 'rule', 'add', ip_cmd_from_should.split(' '))
    end

  end

end
