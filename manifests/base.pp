class network::base ( $networking_ipv6 = 'no',
                      $ipv6forwarding  = 'no',
                      $nozeroconf      = 'yes'){

  file {
    '/etc/sysconfig/network':
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('network/network.erb');
  }

}
