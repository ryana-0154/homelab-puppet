# @summary Configures Vault OIDC authentication with Authentik
#
# @param authentik_client_id
#   OAuth2 Client ID from Authentik provider
# @param authentik_client_secret
#   OAuth2 Client Secret from Authentik provider
# @param authentik_url
#   Base URL of Authentik instance
# @param authentik_app_slug
#   Slug of the Vault application in Authentik
# @param vault_addr
#   Vault API address
# @param vault_token_file
#   Path to file containing Vault token for CLI access
# @param default_policy
#   Default policy to assign to OIDC-authenticated users
# @param admin_groups
#   List of Authentik groups that should get admin policy
#
class homelab::vault::oidc_authentik (
  String $authentik_client_id,
  Sensitive[String] $authentik_client_secret,
  String $authentik_url           = 'http://localhost:9000',
  String $authentik_app_slug      = 'vault',
  String $vault_addr              = 'http://127.0.0.1:8200',
  String $vault_token_file        = '/opt/vault/.root_token',
  String $default_policy          = 'default',
  Array[String] $admin_groups     = [],
) {
  require homelab::vault

  $vault_dir = '/opt/vault'
  $oidc_config_marker = "${vault_dir}/.oidc_configured"
  $oidc_discovery_url = "${authentik_url}/application/o/${authentik_app_slug}/"

  # Script to configure OIDC (only runs once)
  file { "${vault_dir}/configure-oidc.sh":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => epp('homelab/vault/configure-oidc.sh.epp', {
      'vault_addr'              => $vault_addr,
      'vault_token_file'        => $vault_token_file,
      'oidc_discovery_url'      => $oidc_discovery_url,
      'authentik_client_id'     => $authentik_client_id,
      'authentik_client_secret' => $authentik_client_secret.unwrap,
      'default_policy'          => $default_policy,
      'admin_groups'            => $admin_groups,
      'oidc_config_marker'      => $oidc_config_marker,
    }),
  }

  # Run OIDC configuration if not already done
  exec { 'vault-configure-oidc':
    command => "${vault_dir}/configure-oidc.sh",
    creates => $oidc_config_marker,
    require => [
      File["${vault_dir}/configure-oidc.sh"],
      Exec['vault-ensure-running'],
    ],
  }
}
