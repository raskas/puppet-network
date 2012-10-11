
class network::qinqfix {

  file {
    '/sbin/ifup':
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/network/ifup',
      require => Package['initscripts'];
    }

}


define network::interface::ip (
  $ensure='present',
  $enable=true,
  $ipaddr=undef,
  $netmask=undef,
  $ipv6addr=undef,
  $ipv6addr_secondaries=undef,
  $hwaddr=undef,
  $vlan='no',
  $mtu=undef,
  $state=undef,
  $bootproto='static',
  $onboot='yes',
  $onparent=undef ) {

  $device = $name

  if $ipv6addr {
    if $ipv6addr_secondaries {
      $ipv6addresses="${ipv6addr} ${ipv6addr_secondaries}"
    } else {
      $ipv6addresses=$ipv6addr
    }
  } else {
    $ipv6addresses=undef
  }

  if $ipv6addresses {
    $ipv6addrsorted=inline_template("<%= ipv6addresses.split(/\s+/).sort.join(' ') %>")
  } else {
    $ipv6addrsorted=undef
  }

  if $ipv6addrsorted {
    $v6init='yes'
  }

  # Create the network interfaces before their configuration
  #Network_interface <||> -> Network_config <||>

  network_config { $device:
    ensure               => $ensure,
    ipaddr               => $ipaddr,
    netmask              => $netmask,
    ipv6addr             => $ipv6addr,
    ipv6addr_secondaries => $ipv6addr_secondaries,
    vlan      => $vlan,
    hwaddr    => $hwaddr,
    mtu       => $mtu,
    bootproto => $bootproto,
    onboot    => $onboot,
    ipv6init  => $v6init,
    onparent  => $onparent;
  }

  if $enable {
    network_interface { $device:
      ensure    => $ensure,
      ipaddr    => $ipaddr,
      netmask   => $netmask,
      ipv6addr  => $ipv6addrsorted,
      vlan      => $vlan,
      address   => $hwaddr,
      mtu       => $mtu,
      state     => $state
    }
    Network_interface[$device]-> Network_config[$device]
  }
}

define network::interface::bond (
    $ensure    = 'present',
    $ipaddr    = undef,
    $netmask   = undef,
    $state     = 'up',
    $slaves    = [],
    $bootproto = 'static'
  ) {

  $device = $name

  # Create the network interfaces before their configuration
  Network_interface <||> -> Network_config <||>

  network_config { 
    $device:
      ensure    => $ensure,
      ipaddr    => $ipaddr,
      netmask   => $netmask,
      bootproto => $bootproto;
    $slaves:
      ensure    => $ensure,
      bootproto => $bootproto,
      master    => $device,
      slave     => 'yes';
  }


  network_interface {
    $device:
      ensure  => $ensure,
      ipaddr  => $ipaddr,
      netmask => $netmask,
      state   => $state;
    $slaves:
      ensure => $ensure,
      state  => $state,
      master => $device;
  }

}
