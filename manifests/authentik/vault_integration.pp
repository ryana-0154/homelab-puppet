# @summary Sets up complete Vault OIDC integration with Authentik
#
# This class automatically creates the Vault application in Authentik
# and configures Vault to use Authentik as an OIDC provider.
#
# @param authentik_url
#   Base URL of Authentik instance (must be reachable from Vault)
# @param vault_addr
#   Vault API address (used for OIDC callback URLs)
# @param vault_external_addr
#   External Vault address for redirects (defaults to vault_addr)
# @param client_id
#   OAuth2 client ID (auto-generated if not provided)
# @param client_secret
#   OAuth2 client secret (auto-generated if not provided)
# @param vault_token_file
#   Path to Vault root token file
# @param default_policy
#   Default Vault policy for OIDC users
# @param admin_groups
#   Authentik groups that get Vault admin policy
#
class homelab::authentik::vault_integration (
  String $authentik_url                     = 'http://localhost:9000',
  String $vault_addr                        = 'http://127.0.0.1:8200',
  Optional[String] $vault_external_addr     = undef,
  Optional[String] $client_id               = undef,
  Optional[String] $client_secret           = undef,
  String $vault_token_file                  = '/opt/vault/.root_token',
  String $default_policy                    = 'default',
  Array[String] $admin_groups               = [],
) {
  require homelab::authentik
  require homelab::vault

  # Generate deterministic credentials if not provided
  # Uses fqdn_rand_string from stdlib for reproducible randomness
  $actual_client_id = $client_id ? {
    undef   => fqdn_rand_string(32, '', 'vault-oidc-client-id'),
    default => $client_id,
  }

  $actual_client_secret = $client_secret ? {
    undef   => fqdn_rand_string(64, '', 'vault-oidc-client-secret'),
    default => $client_secret,
  }

  $actual_vault_external = $vault_external_addr ? {
    undef   => $vault_addr,
    default => $vault_external_addr,
  }

  # Create Vault application in Authentik via blueprint
  homelab::authentik::oidc_application { 'vault':
    application_name => 'Vault',
    client_id        => $actual_client_id,
    client_secret    => Sensitive($actual_client_secret),
    client_type      => 'confidential',
    redirect_uris    => [
      "${actual_vault_external}/ui/vault/auth/oidc/oidc/callback",
      'http://localhost:8250/oidc/callback',
    ],
    launch_url       => $actual_vault_external,
  }

  # Configure Vault OIDC to use Authentik
  class { 'homelab::vault::oidc_authentik':
    authentik_client_id     => $actual_client_id,
    authentik_client_secret => $actual_client_secret,
    authentik_url           => $authentik_url,
    authentik_app_slug      => 'vault',
    vault_addr              => $vault_addr,
    vault_token_file        => $vault_token_file,
    default_policy          => $default_policy,
    admin_groups            => $admin_groups,
  }
}
