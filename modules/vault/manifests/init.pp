# @summary Deploys HashiCorp Vault for secret management
#
# @param vault_version
#   Docker image tag for Vault
# @param vault_addr
#   Vault API address
# @param disable_mlock
#   Disable mlock (required for Docker without IPC_LOCK)
# @param ui_enabled
#   Enable Vault web UI
#
class vault (
  String $vault_version   = 'latest',
  String $vault_addr      = 'http://127.0.0.1:8200',
  Boolean $disable_mlock  = true,
  Boolean $ui_enabled     = true,
) {
  require docker

  $vault_dir = '/opt/vault'

  # Create Vault directory structure
  file { $vault_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { "${vault_dir}/data":
    ensure  => directory,
    owner   => '100',  # vault user in container
    group   => '1000',
    mode    => '0700',
    require => File[$vault_dir],
  }

  file { "${vault_dir}/logs":
    ensure  => directory,
    owner   => '100',
    group   => '1000',
    mode    => '0755',
    require => File[$vault_dir],
  }

  file { "${vault_dir}/config":
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File[$vault_dir],
  }

  # Deploy Vault configuration
  file { "${vault_dir}/config/vault.hcl":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('vault/vault.hcl.epp', {
      'disable_mlock' => $disable_mlock,
      'ui_enabled'    => $ui_enabled,
    }),
    require => File["${vault_dir}/config"],
    notify  => Exec['vault-docker-compose-up'],
  }

  # Deploy docker-compose.yaml
  file { "${vault_dir}/docker-compose.yaml":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('vault/docker-compose.yaml.epp', {
      'vault_version' => $vault_version,
    }),
    require => File[$vault_dir],
    notify  => Exec['vault-docker-compose-up'],
  }

  # Run docker compose
  exec { 'vault-docker-compose-up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $vault_dir,
    refreshonly => true,
    require     => [
      File["${vault_dir}/config/vault.hcl"],
      File["${vault_dir}/docker-compose.yaml"],
    ],
  }

  # Ensure Vault is running (idempotent check)
  exec { 'vault-ensure-running':
    command => '/usr/bin/docker compose up -d',
    cwd     => $vault_dir,
    unless  => '/usr/bin/docker compose ps --status running | grep -q vault',
    require => [
      File["${vault_dir}/config/vault.hcl"],
      File["${vault_dir}/docker-compose.yaml"],
    ],
  }
}
