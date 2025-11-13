# powerdns::repo
class powerdns::repo inherits powerdns {
  # The repositories of PowerDNS use a version such as '40' for version 4.0
  # and 41 for version 4.1.
  $authoritative_short_version = regsubst($powerdns::authoritative_version, /^(\d+)\.(\d+)(?:\.\d+)?$/, '\\1\\2', 'G')
  $recursor_short_version = regsubst($powerdns::recursor_version, /^(\d+)\.(\d+)(?:\.\d+)?$/, '\\1\\2', 'G')

  case $facts['os']['family'] {
    'RedHat': {
      unless $powerdns::custom_epel {
        include epel
        Class['epel'] -> Yumrepo['powerdns']
      }

      Yumrepo['powerdns'] -> Package <| title == $powerdns::authoritative_package_name |>
      Yumrepo['powerdns-recursor'] -> Package <| title == $powerdns::recursor_package_name |>

      yumrepo { 'powerdns':
        name        => 'powerdns',
        descr       => "PowerDNS repository for PowerDNS Authoritative - version ${powerdns::authoritative_version}",
        baseurl     => "http://repo.powerdns.com/centos/\$basearch/\$releasever/auth-${authoritative_short_version}",
        gpgkey      => 'https://repo.powerdns.com/FD380FBB-pub.asc',
        gpgcheck    => 1,
        enabled     => 1,
        priority    => 90,
        includepkgs => 'pdns*',
      }

      yumrepo { 'powerdns-recursor':
        name        => 'powerdns-recursor',
        descr       => "PowerDNS repository for PowerDNS Recursor - version ${powerdns::recursor_version}",
        baseurl     => "http://repo.powerdns.com/centos/\$basearch/\$releasever/rec-${recursor_short_version}",
        gpgkey      => 'https://repo.powerdns.com/FD380FBB-pub.asc',
        gpgcheck    => 1,
        enabled     => 1,
        priority    => 90,
        includepkgs => 'pdns*',
      }
    }

    'Debian': {
      include apt

      $os = downcase($facts['os']['name'])

      apt::keyring { 'powerdns.asc':
        ensure => present,
        source => 'https://repo.powerdns.com/FD380FBB-pub.asc',
      }

      # Determine if this system supports DEB822 format
      $supports_deb822 = (
        ($facts['os']['name'] == 'Debian' and Integer($facts['os']['release']['major']) >= 12) or
        ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0)
      )

      $auth_release = "${facts['os']['distro']['codename']}-auth-${authoritative_short_version}"
      if $supports_deb822 {
        apt::source { 'powerdns':
          ensure        => present,
          location      => "http://repo.powerdns.com/${os}",
          repos         => 'main',
          release       => $auth_release,
          architecture  => 'amd64',
          keyring       => '/etc/apt/keyrings/powerdns.asc',
          source_format => 'sources',
          require       => Apt::Keyring['powerdns.asc'],
        }
      } else {
        apt::source { 'powerdns':
          ensure       => present,
          location     => "http://repo.powerdns.com/${os}",
          repos        => 'main',
          release      => $auth_release,
          architecture => 'amd64',
          keyring      => '/etc/apt/keyrings/powerdns.asc',
          require      => Apt::Keyring['powerdns.asc'],
        }
      }

      $rec_release = "${facts['os']['distro']['codename']}-rec-${recursor_short_version}"
      if $supports_deb822 {
        apt::source { 'powerdns-recursor':
          ensure        => present,
          location      => "http://repo.powerdns.com/${os}",
          repos         => 'main',
          release       => $rec_release,
          architecture  => 'amd64',
          keyring       => '/etc/apt/keyrings/powerdns.asc',
          source_format => 'sources',
          require       => Apt::Source['powerdns'],
        }
      } else {
        apt::source { 'powerdns-recursor':
          ensure       => present,
          location     => "http://repo.powerdns.com/${os}",
          repos        => 'main',
          release      => $rec_release,
          architecture => 'amd64',
          keyring      => '/etc/apt/keyrings/powerdns.asc',
          require      => Apt::Source['powerdns'],
        }
      }

      # Cleanup old .list format files if migrating to DEB822
      if $supports_deb822 {
        file { '/etc/apt/sources.list.d/powerdns.list':
          ensure => absent,
        }

        file { '/etc/apt/sources.list.d/powerdns-recursor.list':
          ensure => absent,
        }
      }

      apt::pin { 'powerdns':
        priority   => 600,
        packages   => 'pdns-*',
        originator => 'PowerDNS',
        codename   => $auth_release,
        require    => Apt::Source['powerdns-recursor'],
      }

      # authoritative apt source contains pdns-recursor
      # this will make it possible to have different versions
      apt::pin { 'powerdns-recursor':
        priority   => 700,
        packages   => 'pdns-recursor',
        originator => 'PowerDNS',
        codename   => $rec_release,
        require    => Apt::Pin['powerdns'],
      }

      Apt::Pin['powerdns'] -> Package <| title == $powerdns::authoritative_package_name |>
      Apt::Pin['powerdns'] -> Package <| title == $powerdns::recursor_package_name |>
    }

    'FreeBSD','Archlinux': {
      # Use the official pkg repository
    }

    default: {
      fail("${facts['os']['family']} is not supported yet.")
    }
  }
}
