# @summary Configures Vault AppRole auth for Puppet-managed nodes
#
# @param role_name
#   Name of the AppRole role
# @param policies
#   Policies to attach to the role
# @param token_ttl
#   Token TTL
# @param token_max_ttl
#   Maximum token TTL
# @param secret_id_ttl
#   Secret ID TTL (0 for no expiration)
#
class homelab::vault::approle (
  String $role_name                = 'puppet-agent',
  Array[String] $policies          = ['puppet-secrets'],
  String $token_ttl                = '1h',
  String $token_max_ttl            = '4h',
  String $secret_id_ttl            = '0',
  String $vault_token_file         = '/opt/vault/.root_token',
) {
  require homelab::vault

  $vault_dir = '/opt/vault'
  $approle_marker = "${vault_dir}/.approle_configured"
  $setup_script = "${vault_dir}/setup-approle.sh"

  # Create puppet-secrets policy
  file { "${vault_dir}/puppet-secrets-policy.hcl":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(POLICY),
      # Policy for Puppet-managed nodes to read secrets
      path "secret/data/puppet/*" {
        capabilities = ["read", "list"]
      }
      path "secret/metadata/puppet/*" {
        capabilities = ["read", "list"]
      }
      | POLICY
    require => File[$vault_dir],
  }

  # Setup script for AppRole
  file { $setup_script:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => epp('homelab/vault/setup-approle.sh.epp', {
      'vault_token_file' => $vault_token_file,
      'role_name'        => $role_name,
      'policies'         => $policies,
      'token_ttl'        => $token_ttl,
      'token_max_ttl'    => $token_max_ttl,
      'secret_id_ttl'    => $secret_id_ttl,
      'approle_marker'   => $approle_marker,
    }),
    require => File["${vault_dir}/puppet-secrets-policy.hcl"],
  }

  exec { 'setup-vault-approle':
    command => $setup_script,
    creates => $approle_marker,
    require => File[$setup_script],
  }
}
