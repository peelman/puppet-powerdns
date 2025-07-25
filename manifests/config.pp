# @summary Manage powerdns settings
#
# @param setting
#   The setting you want to change
# @param value
#   The value for the above setting
# @param ensure
#   Specify whether or not this configuration should be present
# @param type
#   If this configuration applies to the authoritative server
#   or the recursor
define powerdns::config (
  String[1] $setting = $title,
  Powerdns::ConfigValue $value = '',
  Enum['present', 'absent'] $ensure = 'present',
  Enum['authoritative', 'recursor'] $type = 'authoritative'
) {
  $empty_value_allowed = [
    'gmysql-dnssec',
    'only-notify',
    'allow-notify-from',
    'security-poll-suffix',
    'local-ipv6',
  ]
  unless $ensure == 'absent' or ($setting in $empty_value_allowed) {
    assert_type(Variant[String[1], Integer, Boolean, Sensitive[String[1]]], $value) |$_expected, $_actual| {
      fail("Value for ${setting} can't be empty.")
    }
  }

  if $setting == 'gmysql-dnssec' {
    $line = $setting
  } else {
    $line = $value =~ Sensitive ? {
      true => "${setting}=${value.unwrap}",
      false => "${setting}=${value}"
    }
  }

  if $type == 'authoritative' {
    $path            = $powerdns::authoritative_config
    $require_package = $powerdns::authoritative_package_name
    $notify_service  = 'pdns'
  } else {
    $path            = $powerdns::recursor_config
    $require_package = $powerdns::recursor_package_name
    $notify_service  = 'pdns-recursor'
  }

  file_line { "powerdns-config-${setting}-${path}":
    ensure            => $ensure,
    path              => $path,
    line              => $line,
    match             => "^${setting}=",
    match_for_absence => true, # ignored when ensure == 'present'
    require           => Package[$require_package],
    notify            => Service[$notify_service],
  }
}
