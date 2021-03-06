Puppet::Type.type(:network_route).provide(:network_scripts) do

  commands :ip => "/sbin/ip"
  defaultfor :operatingsystem => [:redhat, :fedora, :centos]

  @@config_dir = '/etc/sysconfig/network-scripts/'
  @@default_inet_target  = 'route-eth0'
  @@default_inet6_target = 'route6-eth0'

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
    ip('-family', self.family, 'route', 'show', 'table', 'all').each do |ip|
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

  def via
    @@config[@resource[:name]]['via']
  end

  def via=(value)
    delete_resource
    create_resource
  end

  def to
    @@config[@resource[:name]]['to']
  end

  def to=(value)
    delete_resource
    create_resource
  end

  def device
    @@config[@resource[:name]]['device']
  end

  def device=(value)
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

  # Helper functions
  #####

  def load_on_disk_configuration
    config = Hash.new
    Dir.glob(@@config_dir + 'route{6,}-*').each do |file|
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

          # search via
          if line_arr.index('via').nil?
            config[name]['via'] = nil
          else
            config[name]['via'] = line_arr[line_arr.index('via').to_i+1]
          end

          # search to
          if line_arr.index('to').nil?
            config[name]['to'] = nil
          else
            config[name]['to'] = line_arr[line_arr.index('to').to_i+1]
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
          if /route6-/.match(config[name]['file']) 
            config[name]['family'] = 'inet6'
          else
            config[name]['family'] = 'inet'
          end

          # device
          config[name]['device'] = config[name]['file'].scan(/route6?-(.*)$/).to_s

        end
      end
    end

    return config
  end

  # Build the 'ip route add/del' command based on information received from the file
  def ip_cmd_from_file

    ip_cmd = ''
    ip_cmd += 'to '     + self.to     + ' ' if ! self.to.nil?     && ! self.to.empty?
    ip_cmd += 'via '    + self.via    + ' ' if ! self.via.nil?    && ! self.via.empty?
    ip_cmd += 'dev '    + self.device + ' ' if ! self.device.nil? && ! self.device.empty?
    ip_cmd += 'table '  + self.table  + ' ' if ! self.table.nil?  && ! self.table.empty?
    return ip_cmd

  end

  # Build the 'ip route add/del' command based on information received from the resource
  def ip_cmd_from_should

    ip_cmd  = ''
    ip_cmd += 'to '     + @resource.should(:to)     + ' ' if @resource.should(:to)
    ip_cmd += 'via '    + @resource.should(:via)    + ' ' if @resource.should(:via)
    ip_cmd += 'dev '    + @resource.should(:device) + ' ' if @resource.should(:device)
    ip_cmd += 'table '  + @resource.should(:table)  + ' ' if @resource.should(:table)
    return ip_cmd

  end

  # Build a regex which will match the 'ip route show table all' output based on information received from the file
  def ip_output_from_file

    ip_output = '^'
    ip_output +=            self.to     + ' '   if ! self.to.nil?     && ! self.to.empty?
    ip_output += 'via '   + self.via    + ' '   if ! self.via.nil?    && ! self.via.empty?
    ip_output += 'dev '   + self.device + '\s+' if ! self.device.nil? && ! self.device.empty?
    ip_output += 'table ' + self.table  + ' '   if ! self.table.nil?  && ! self.table.empty?
    return ip_output

  end

  # Build a regex which will match the 'ip rule show' output based on information from the resource
  def ip_output_from_should

    ip_output = '^'
    ip_output +=            @resource.should(:to)     + ' '   if @resource.should(:to)
    ip_output += 'via '   + @resource.should(:via)    + ' '   if @resource.should(:via)
    ip_output += 'dev '   + @resource.should(:device) + '\s+' if @resource.should(:device)
    ip_output += 'table ' + @resource.should(:table)  + ' '   if @resource.should(:table)
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
    ip('-family', self.family, 'route', 'show', 'table', 'all').each do |ip|
      count += 1 if ip =~ /#{ip_output_from_file}/
    end

    # Delete every occurence of the rule
    if count > 0
      ip('-family', self.family, 'route', 'del', ip_cmd_from_file.split(' '))
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
      target += 'route-'
    else
      target += 'route6-'
    end
    target += @resource.should(:device)

    # Append the 'ip_cmd_from_should' string to the target file
    File.open(target, 'a+') { |f| f.write(ip_cmd_from_should + '# ' + @resource[:name] + "\n") }

  end

  def create_system_resource

    # Count the occurences of the rule
    count = 0
    ip('-family', @resource.should(:family), 'route', 'show', 'table', 'all').each do |ip|
      count += 1 if ip =~ /#{ip_output_from_should}/
    end

    # Add the rule if it wasn't found
    if count == 0
      ip('-family', @resource.should(:family), 'route', 'add', ip_cmd_from_should.split(' '))
    end

  end

end
