# @summary Deploys Authentik identity provider via Docker
#
# @param authentik_version
#   Docker image tag for Authentik
# @param authentik_secret_key
#   Secret key for Authentik (generated if not provided)
# @param postgres_password
#   PostgreSQL password (generated if not provided)
# @param authentik_port
#   HTTP port for Authentik
# @param authentik_port_https
#   HTTPS port for Authentik
#
class homelab::authentik (
  String $authentik_version            = 'latest',
  Optional[String] $authentik_secret_key = undef,
  Optional[String] $postgres_password    = undef,
  Integer $authentik_port               = 9000,
  Integer $authentik_port_https         = 9443,
) {
  require homelab::docker

  $authentik_dir = '/opt/authentik'

  # Create Authentik directory structure
  file { $authentik_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { ["${authentik_dir}/database", "${authentik_dir}/redis", "${authentik_dir}/media", "${authentik_dir}/templates", "${authentik_dir}/certs"]:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File[$authentik_dir],
  }

  # Generate secret key if not provided
  $secret_key_file = "${authentik_dir}/.secret_key"
  $pg_pass_file = "${authentik_dir}/.pg_pass"

  if $authentik_secret_key {
    file { $secret_key_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $authentik_secret_key,
      require => File[$authentik_dir],
    }
  } else {
    exec { 'generate-authentik-secret-key':
      command => "/usr/bin/openssl rand -hex 32 > ${secret_key_file} && chmod 600 ${secret_key_file}",
      creates => $secret_key_file,
      require => File[$authentik_dir],
    }
  }

  if $postgres_password {
    file { $pg_pass_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $postgres_password,
      require => File[$authentik_dir],
    }
  } else {
    exec { 'generate-authentik-pg-password':
      command => "/usr/bin/openssl rand -hex 16 > ${pg_pass_file} && chmod 600 ${pg_pass_file}",
      creates => $pg_pass_file,
      require => File[$authentik_dir],
    }
  }

  # Deploy docker-compose.yaml
  file { "${authentik_dir}/docker-compose.yaml":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('homelab/authentik/docker-compose.yaml.epp', {
      'authentik_version'    => $authentik_version,
      'authentik_port'       => $authentik_port,
      'authentik_port_https' => $authentik_port_https,
    }),
    require => File[$authentik_dir],
    notify  => Exec['authentik-docker-compose-up'],
  }

  # Generate .env file from secrets (runs after secret files are created)
  $env_file = "${authentik_dir}/.env"
  $secret_key_resource = $authentik_secret_key ? {
    undef   => Exec['generate-authentik-secret-key'],
    default => File[$secret_key_file],
  }
  $pg_pass_resource = $postgres_password ? {
    undef   => Exec['generate-authentik-pg-password'],
    default => File[$pg_pass_file],
  }

  exec { 'generate-authentik-env':
    command => "/bin/bash -c 'echo \"AUTHENTIK_SECRET_KEY=\$(cat ${secret_key_file})\" > ${env_file} && echo \"PG_PASS=\$(cat ${pg_pass_file})\" >> ${env_file} && chmod 600 ${env_file}'",
    creates => $env_file,
    require => [
      $secret_key_resource,
      $pg_pass_resource,
    ],
    notify  => Exec['authentik-docker-compose-up'],
  }

  # Run docker compose
  exec { 'authentik-docker-compose-up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $authentik_dir,
    refreshonly => true,
    require     => [
      File["${authentik_dir}/docker-compose.yaml"],
      Exec['generate-authentik-env'],
    ],
  }

  # Ensure Authentik is running (idempotent check)
  exec { 'authentik-ensure-running':
    command => '/usr/bin/docker compose up -d',
    cwd     => $authentik_dir,
    unless  => '/usr/bin/docker compose ps --status running | grep -q authentik-server',
    require => [
      File["${authentik_dir}/docker-compose.yaml"],
      Exec['generate-authentik-env'],
    ],
  }
}
