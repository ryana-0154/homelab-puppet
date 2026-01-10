# @summary Deploys Grafana Alloy for log/metric/trace forwarding to Grafana Cloud
#
# @param grafana_cloud_api_key
#   API key for Grafana Cloud authentication (fetch from Vault)
# @param grafana_cloud_prometheus_url
#   Prometheus remote write endpoint URL
# @param grafana_cloud_prometheus_username
#   Prometheus/Mimir instance ID
# @param grafana_cloud_loki_url
#   Loki push endpoint URL
# @param grafana_cloud_loki_username
#   Loki instance ID
# @param grafana_cloud_tempo_url
#   Tempo OTLP endpoint URL
# @param grafana_cloud_tempo_username
#   Tempo instance ID
# @param alloy_version
#   Docker image tag for Alloy
#
class alloy (
  String $grafana_cloud_api_key,
  String $grafana_cloud_prometheus_url,
  String $grafana_cloud_prometheus_username,
  String $grafana_cloud_loki_url,
  String $grafana_cloud_loki_username,
  String $grafana_cloud_tempo_url,
  String $grafana_cloud_tempo_username,
  String $alloy_version = 'latest',
) {
  require docker

  $alloy_dir = '/opt/alloy'

  # Create Alloy directory
  file { $alloy_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Deploy Alloy configuration
  file { "${alloy_dir}/config.alloy":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => epp('alloy/config.alloy.epp', {
      'prometheus_url'      => $grafana_cloud_prometheus_url,
      'prometheus_username' => $grafana_cloud_prometheus_username,
      'loki_url'            => $grafana_cloud_loki_url,
      'loki_username'       => $grafana_cloud_loki_username,
      'tempo_url'           => $grafana_cloud_tempo_url,
      'tempo_username'      => $grafana_cloud_tempo_username,
      'api_key'             => $grafana_cloud_api_key,
    }),
    notify  => Exec['alloy-docker-compose-up'],
  }

  # Deploy docker-compose.yaml
  file { "${alloy_dir}/docker-compose.yaml":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('alloy/docker-compose.yaml.epp', {
      'alloy_version' => $alloy_version,
    }),
    notify  => Exec['alloy-docker-compose-up'],
  }

  # Run docker compose
  exec { 'alloy-docker-compose-up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $alloy_dir,
    refreshonly => true,
    require     => [
      File["${alloy_dir}/config.alloy"],
      File["${alloy_dir}/docker-compose.yaml"],
    ],
  }

  # Ensure Alloy is running (idempotent check)
  exec { 'alloy-ensure-running':
    command => '/usr/bin/docker compose up -d',
    cwd     => $alloy_dir,
    unless  => '/usr/bin/docker compose ps --status running | grep -q alloy',
    require => [
      File["${alloy_dir}/config.alloy"],
      File["${alloy_dir}/docker-compose.yaml"],
    ],
  }
}
