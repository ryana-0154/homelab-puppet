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
# @param auto_unseal
#   Enable automatic unsealing on startup
# @param unseal_keys
#   Array of unseal keys (required if auto_unseal is true)
#
class homelab::vault (
  String $vault_version          = 'latest',
  String $vault_addr             = 'http://127.0.0.1:8200',
  Boolean $disable_mlock         = true,
  Boolean $ui_enabled            = true,
  Boolean $auto_unseal           = false,
  Optional[Array[String]] $unseal_keys = undef,
) {
  require homelab::docker

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
    content => epp('homelab/vault/vault.hcl.epp', {
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
    content => epp('homelab/vault/docker-compose.yaml.epp', {
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

  # Auto-unseal configuration
  if $auto_unseal and $unseal_keys {
    # Validate we have at least 3 keys (default threshold)
    if $unseal_keys.length < 3 {
      fail('auto_unseal requires at least 3 unseal_keys (default Vault threshold)')
    }
    # Store unseal keys securely
    file { "${vault_dir}/.unseal_keys":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => "${unseal_keys.join("\n")}\n",
      require => File[$vault_dir],
    }

    # Auto-unseal script
    file { "${vault_dir}/unseal.sh":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => epp('homelab/vault/unseal.sh.epp', {
        'vault_dir'  => $vault_dir,
        'vault_addr' => $vault_addr,
      }),
      require => File[$vault_dir],
    }

    # Systemd service for auto-unseal
    file { '/etc/systemd/system/vault-unseal.service':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('homelab/vault/vault-unseal.service.epp', {
        'vault_dir' => $vault_dir,
      }),
      notify  => Exec['systemd-daemon-reload-vault'],
    }

    exec { 'systemd-daemon-reload-vault':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
    }

    service { 'vault-unseal':
      ensure  => running,
      enable  => true,
      require => [
        File['/etc/systemd/system/vault-unseal.service'],
        File["${vault_dir}/unseal.sh"],
        File["${vault_dir}/.unseal_keys"],
        Exec['systemd-daemon-reload-vault'],
      ],
    }
  }
}
