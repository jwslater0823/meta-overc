class network_prime
(
  $container = $network_prime::container,
  $network_device = $network_prime::network_device,
) {
  # Let networkd bring up the physical interface - network-prime container
  file { '20-br-ext-phys.network':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/network/20-br-ext-phys.network",
    content => template('network_prime/20-br-ext-phys.network.erb'),
  }

  # Let networkd bring up and configure br-ext - network-prime container
  file { '25-br-ext.network':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/network/25-br-ext.network",
    source => 'puppet:///modules/network_prime/25-br-ext.network',
  }

  # Let networkd configure br-int - network-prime container
  file { '25-br-int.network':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/network/25-br-int.network",
    source => 'puppet:///modules/network_prime/25-br-int.network',
  }

  # Let networkd configure eth0 (br-int virtual interface) - network-prime container
  file { '20-br-int-virt.network':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/network/20-br-int-virt.network",
    source => 'puppet:///modules/network_prime/20-br-int-virt.network',
  }

  # Remove the default networking configuration - network-prime container
  file { '20-wired.network':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/network/20-wired.network",
    ensure => 'absent',
  }

  # Create the br-int OVS bridge
  vs_bridge { 'br-int':
    ensure => present,
    before => File['25-br-int.network.essential'],
  }

  # Let networkd configure br-int - essential
  file { '25-br-int.network.essential':
    path => "/etc/systemd/network/25-br-int.network",
    source => 'puppet:///modules/network_prime/25-br-int.network.essential',
  }

  # Remove the default networking configuration - network-prime container
  file { '20-wired.network.essential':
    path => "/etc/systemd/network/20-wired.network",
    ensure => 'absent',
  }

  # Service file to clone MAC address from external interface to br-ext.
  # Copy the service file and create a link to ensure it is 'enabled'
  file { 'mac-clone-phys-to-br-ext.service':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/system/mac-clone-phys-to-br-ext.service",
    content => template('network_prime/mac-clone-phys-to-br-ext.erb'),
    before => File['mac-clone-phys-to-br-ext-link'],
  }
  file { 'mac-clone-phys-to-br-ext-link':
    ensure => 'link',
    target => "../mac-clone-phys-to-br-ext.service",
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/system/multi-user.target.wants/mac-clone-phys-to-br-ext.service",
  }

  # Service file and script to make sure the network-prime is properly
  # configured (OVS, iptables...) on boot.
  file { 'overc-network-prime.service':
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/system/overc-network-prime.service",
    source => 'puppet:///modules/network_prime/overc-network-prime.service',
    before => File['overc-network-prime.service.link'],
  }
  file { 'overc-network-prime.service.link':
    ensure => 'link',
    target => "../overc-network-prime.service",
    path => "/var/lib/lxc/$container/rootfs/etc/systemd/system/multi-user.target.wants/overc-network-prime.service",
  }
  file { '/etc/overc':
     path => "/var/lib/lxc/$container/rootfs/etc/overc",
     ensure => 'directory',
     before => File['network_prime.sh'],
  }
  file { 'network_prime.sh':
    path => "/var/lib/lxc/$container/rootfs/etc/overc/network_prime.sh",
    content => template('network_prime/network_prime.sh.erb'),
    mode => '0750',
  }

  # The network-prime has to be able to forward external traffic
  file_line { 'enable-ip-forwarding-config':
    path => "/var/lib/lxc/$container/rootfs/etc/sysctl.conf",
    match => '.*net.ipv4.ip_forward=[01]',
    line => 'net.ipv4.ip_forward=1',
  }

  # Disable configuration of the network prime on subsequent boots
  file_line { 'disable-network-prime-setup':
    path => '/etc/puppet/manifests/site.pp',
    match => '^\$configure_network_prime = true$',
    line => '#$configure_network_prime = true'
  }
}
