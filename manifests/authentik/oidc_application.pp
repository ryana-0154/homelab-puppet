# @summary Creates an OIDC application in Authentik via blueprint
#
# @param application_name
#   Display name for the application
# @param client_id
#   OAuth2 client ID
# @param client_secret
#   OAuth2 client secret (required for confidential clients)
# @param redirect_uris
#   Array of allowed redirect URIs
# @param launch_url
#   URL to launch the application (optional)
# @param client_type
#   OAuth2 client type (confidential or public)
#
define homelab::authentik::oidc_application (
  String $client_id,
  String $application_name                       = $title,
  Optional[Sensitive[String]] $client_secret     = undef,
  Array[String] $redirect_uris                   = [],
  Optional[String] $launch_url                   = undef,
  Enum['confidential', 'public'] $client_type    = 'confidential',
) {
  include homelab::authentik

  $authentik_dir = '/opt/authentik'
  $slug = regsubst(downcase($title), '[^a-z0-9]', '-', 'G')
  $blueprint_file = "${authentik_dir}/blueprints/${slug}.yaml"

  # Validate that confidential clients have a secret
  if $client_type == 'confidential' and $client_secret == undef {
    fail("OIDC application '${title}' is confidential but no client_secret was provided")
  }

  # Unwrap sensitive value for template
  $client_secret_value = $client_secret ? {
    undef   => undef,
    default => $client_secret.unwrap,
  }

  file { $blueprint_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => epp('homelab/authentik/oidc_blueprint.yaml.epp', {
      'application_name' => $application_name,
      'slug'             => $slug,
      'client_id'        => $client_id,
      'client_secret'    => $client_secret_value,
      'client_type'      => $client_type,
      'redirect_uris'    => $redirect_uris,
      'launch_url'       => $launch_url,
    }),
    require => File["${authentik_dir}/blueprints"],
    notify  => Exec['authentik-docker-compose-up'],
  }
}
