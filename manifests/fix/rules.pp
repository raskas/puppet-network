
class network::fix::rules {

  file {
    '/etc/sysconfig/network-scripts/ifup-routes':
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/network/fix/ifup-routes',
      require => Package['initscripts'];
    '/etc/sysconfig/network-scripts/ifdown-routes':
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/network/fix/ifdown-routes',
      require => Package['initscripts'];
    '/etc/sysconfig/network-scripts/ifup-ipv6':
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/network/fix/ifup-ipv6',
      require => Package['initscripts'];
    '/etc/sysconfig/network-scripts/ifdown-ipv6':
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/network/fix/ifdown-ipv6',
      require => Package['initscripts'];
  }

}

