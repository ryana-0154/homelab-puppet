# @summary Deploys Vault Agent to sync secrets from Vault to local files
#
# @param vault_addr
#   Vault server address
# @param role_id
#   AppRole role ID
# @param secret_id
#   AppRole secret ID (store this in Vault itself for bootstrapping, or pass via Foreman)
# @param secrets
#   Hash of secrets to sync: { 'destination_path' => { 'vault_path' => '...', 'template' => '...' } }
# @param vault_version
#   Vault binary version to install
#
# @example
#   class { 'homelab::vault_agent':
#     vault_addr => 'http://vault.home:8200',
#     role_id    => 'xxx',
#     secret_id  => 'yyy',
#     secrets    => {
#       '/etc/myapp/db_password' => {
#         'vault_path' => 'secret/data/puppet/myapp',
#         'field'      => 'db_password',
#         'owner'      => 'myapp',
#         'mode'       => '0600',
#       },
#     },
#   }
#
class homelab::vault_agent (
  String $vault_addr,
  String $role_id,
  String $secret_id,
  Hash $secrets                    = {},
  String $vault_version            = '1.21.2',
  String $agent_user               = 'root',
  String $agent_group              = 'root',
) {
  # Required packages
  ensure_packages(['unzip', 'curl'], { ensure => present })

  $agent_dir = '/opt/vault-agent'
  $config_file = "${agent_dir}/agent.hcl"
  $role_id_file = "${agent_dir}/role_id"
  $secret_id_file = "${agent_dir}/secret_id"

  # Create directory structure
  file { $agent_dir:
    ensure => directory,
    owner  => $agent_user,
    group  => $agent_group,
    mode   => '0750',
  }

  file { "${agent_dir}/secrets":
    ensure  => directory,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0750',
    require => File[$agent_dir],
  }

  # Install Vault binary if not using Docker
  $vault_zip = "/tmp/vault_${vault_version}_linux_amd64.zip"
  $vault_bin = '/usr/local/bin/vault'

  exec { 'download-vault':
    command => "/usr/bin/curl -sLo ${vault_zip} https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip",
    creates => $vault_zip,
    unless  => "/usr/bin/test -x ${vault_bin} && ${vault_bin} version | grep -q ${vault_version}",
    require => Package['curl'],
  }

  exec { 'install-vault':
    command => "/usr/bin/unzip -o ${vault_zip} -d /usr/local/bin && chmod +x ${vault_bin}",
    creates => $vault_bin,
    require => [Exec['download-vault'], Package['unzip']],
  }

  # Store AppRole credentials
  file { $role_id_file:
    ensure  => file,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0600',
    content => $role_id,
    require => File[$agent_dir],
    notify  => Service['vault-agent'],
  }

  file { $secret_id_file:
    ensure  => file,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0600',
    content => $secret_id,
    require => File[$agent_dir],
    notify  => Service['vault-agent'],
  }

  # Generate agent config
  file { $config_file:
    ensure  => file,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0640',
    content => epp('homelab/vault_agent/agent.hcl.epp', {
      'vault_addr'      => $vault_addr,
      'role_id_file'    => $role_id_file,
      'secret_id_file'  => $secret_id_file,
      'secrets'         => $secrets,
      'agent_dir'       => $agent_dir,
    }),
    require => File[$agent_dir],
    notify  => Service['vault-agent'],
  }

  # Create secret destination directories and set permissions
  $secrets.each |$dest_path, $config| {
    $dest_dir = dirname($dest_path)
    $owner = $config['owner'] ? { undef => 'root', default => $config['owner'] }
    $group = $config['group'] ? { undef => 'root', default => $config['group'] }
    $mode = $config['mode'] ? { undef => '0600', default => $config['mode'] }

    # Ensure parent directory exists
    exec { "mkdir-${dest_dir}":
      command => "/usr/bin/mkdir -p ${dest_dir}",
      creates => $dest_dir,
    }
  }

  # Systemd service
  file { '/etc/systemd/system/vault-agent.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('homelab/vault_agent/vault-agent.service.epp', {
      'config_file' => $config_file,
      'agent_user'  => $agent_user,
      'agent_group' => $agent_group,
    }),
    notify  => Exec['vault-agent-systemd-reload'],
  }

  exec { 'vault-agent-systemd-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  service { 'vault-agent':
    ensure  => running,
    enable  => true,
    require => [
      File[$config_file],
      File[$role_id_file],
      File[$secret_id_file],
      Exec['install-vault'],
      Exec['vault-agent-systemd-reload'],
    ],
  }
}
