# @summary Installs and configures Docker
#
# @param docker_compose_version
#   Version of Docker Compose plugin to install
#
class homelab::docker (
  String $docker_compose_version = '2.24.0',
) {
  # Install prerequisites
  package { ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg']:
    ensure => present,
  }

  # Add Docker's official GPG key
  exec { 'docker-gpg-key':
    command => '/usr/bin/curl -fsSL https://download.docker.com/linux/ubuntu/gpg | /usr/bin/gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg',
    creates => '/usr/share/keyrings/docker-archive-keyring.gpg',
    require => Package['curl', 'gnupg'],
  }

  # Add Docker repository
  file { '/etc/apt/sources.list.d/docker.list':
    ensure  => file,
    content => "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${facts['os']['distro']['codename']} stable\n",
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
