# @summary Installs and configures Docker
#
# Supports both Debian/Ubuntu and RHEL/Rocky Linux systems.
#
class homelab::docker {
  case $facts['os']['family'] {
    'RedHat': {
      # Install prerequisites
      package { 'yum-utils':
        ensure => present,
      }

      # Add Docker repository
      exec { 'docker-repo-add':
        command => '/usr/bin/dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo',
        creates => '/etc/yum.repos.d/docker-ce.repo',
        require => Package['yum-utils'],
      }

      # Install Docker packages
      package { ['docker-ce', 'docker-ce-cli', 'containerd.io', 'docker-compose-plugin']:
        ensure  => present,
        require => Exec['docker-repo-add'],
      }

      # Ensure Docker service is running
      service { 'docker':
        ensure  => running,
        enable  => true,
        require => Package['docker-ce'],
      }
    }
    'Debian': {
      # Detect distro (ubuntu vs debian) and architecture
      $distro = $facts['os']['name'] ? {
        'Ubuntu' => 'ubuntu',
        default  => 'debian',
      }

      $arch = $facts['os']['architecture'] ? {
        'aarch64' => 'arm64',
        'armv7l'  => 'armhf',
        'x86_64'  => 'amd64',
        default   => 'amd64',
      }

      # Install prerequisites
      package { ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg']:
        ensure => present,
      }

      # Ensure keyrings directory exists
      file { '/usr/share/keyrings':
        ensure => directory,
        mode   => '0755',
      }

      # Add Docker's official GPG key
      exec { 'docker-gpg-key':
        command => "/usr/bin/curl -fsSL https://download.docker.com/linux/${distro}/gpg | /usr/bin/gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
        creates => '/usr/share/keyrings/docker-archive-keyring.gpg',
        require => [Package['curl', 'gnupg'], File['/usr/share/keyrings']],
      }

      # Add Docker repository
      file { '/etc/apt/sources.list.d/docker.list':
        ensure  => file,
        content => "deb [arch=${arch} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${distro} ${facts['os']['distro']['codename']} stable\n",
        require => Exec['docker-gpg-key'],
        notify  => Exec['apt-update-docker'],
      }

      exec { 'apt-update-docker':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
      }

      # Install Docker packages
      package { ['docker-ce', 'docker-ce-cli', 'containerd.io', 'docker-compose-plugin']:
        ensure  => present,
        require => [
          File['/etc/apt/sources.list.d/docker.list'],
          Exec['apt-update-docker'],
        ],
      }

      # Ensure Docker service is running
      service { 'docker':
        ensure  => running,
        enable  => true,
        require => Package['docker-ce'],
      }
    }
    default: {
      fail("Unsupported OS family: ${facts['os']['family']}")
    }
  }
}
