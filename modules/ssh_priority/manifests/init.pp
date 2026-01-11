# @summary Ensures SSH sessions have priority access to system resources
#
# Configures systemd resource controls and OOM killer protection to ensure
# SSH remains accessible even when the system is under extreme resource pressure.
#
# @param oom_score_adjust
#   OOM killer score adjustment. -1000 means never kill.
# @param cpu_weight
#   CPU scheduling weight (1-10000, default 100). Higher = more priority.
# @param io_weight
#   I/O scheduling weight (1-10000, default 100). Higher = more priority.
# @param memory_low
#   Memory reservation for SSH service. Protects this amount from reclaim.
# @param nice_level
#   Process nice level (-20 to 19). Lower = higher priority.
# @param manage_service
#   Whether to manage the sshd service.
#
class ssh_priority (
  Integer[-1000, 1000] $oom_score_adjust = -1000,
  Integer[1, 10000]    $cpu_weight       = 1000,
  Integer[1, 10000]    $io_weight        = 1000,
  String               $memory_low       = '64M',
  Integer[-20, 19]     $nice_level       = -10,
  Boolean              $manage_service   = true,
) {
  # Determine the correct sshd service name
  $sshd_service = $facts['os']['family'] ? {
    'Debian' => 'ssh',
    default  => 'sshd',
  }

  # Create systemd override directory
  file { "/etc/systemd/system/${sshd_service}.service.d":
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Deploy systemd override for resource priority
  file { "/etc/systemd/system/${sshd_service}.service.d/priority.conf":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('ssh_priority/priority.conf.epp', {
      oom_score_adjust => $oom_score_adjust,
      cpu_weight       => $cpu_weight,
      io_weight        => $io_weight,
      memory_low       => $memory_low,
      nice_level       => $nice_level,
    }),
    require => File["/etc/systemd/system/${sshd_service}.service.d"],
    notify  => Exec['ssh_priority_systemd_reload'],
  }

  # Reload systemd when override changes
  exec { 'ssh_priority_systemd_reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $manage_service {
    # Ensure sshd is running and restart on config changes
    service { $sshd_service:
      ensure    => running,
      enable    => true,
      subscribe => Exec['ssh_priority_systemd_reload'],
    }
  }
}
