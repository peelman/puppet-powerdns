# PowerDNS

[![Build Status](https://github.com/voxpupuli/puppet-powerdns/workflows/CI/badge.svg)](https://github.com/voxpupuli/puppet-powerdns/actions) [![Puppet Forge](https://img.shields.io/puppetforge/v/voxpupuli/powerdns.svg?maxAge=2592000?style=plastic)](https://forge.puppet.com/voxpupuli/powerdns)

This module can be used to configure both the PowerDNS recursor and authoritative server.

## Examples

### Installation and configuration

This will install the authoritative PowerDNS server which includes the
MySQL server and the management of the database and its tables. This is
the bare minimum.

```puppet
class { 'powerdns':
  db_password      => 's0m4r4nd0mp4ssw0rd',
  db_root_password => 'v3rys3c4r3',
}
```

If you want to install both the recursor and the authoritative server on the
same node it is recommended to have the services listen on their own IP
address. The example below needs to be adjusted to use the ip addresses of your
server.

This may fail the first time on Debian-based distro's.

```puppet
powerdns::config { 'authoritative-local-address':
  type    => 'authoritative',
  setting => 'local-address',
  value   => '127.0.0.1',
}
powerdns::config { 'recursor-local-address':
  type    => 'recursor',
  setting => 'local-address',
  value   => '127.0.0.2',
}
class { 'powerdns':
  db_password      => 's0m4r4nd0mp4ssw0rd',
  db_root_password => 'v3rys3c4r3',
  recursor         => true,
}
```

### Recursor forward zones

Multiple forward zones can be configured using `powerdns::forward_zones`.

```puppet
include powerdns::recursor
```

The configuration will be serialized into `forward-zones-file` config file.

```yaml
powerdns::forward_zones:
  'example.com': 10.0.0.1
  'foo': 192.168.1.1
   # recurse queries
  '+.': 1.1.1.1;8.8.8.8;8.8.4.4
```

### Backends

The default backend is MySQL. It also comes with support for PostgreSQL, Bind,
LDAP, SQLite and lmdb.

If you don't specify the backend it assumes you will use MySQL.

```puppet
class { 'powerdns':
  backend     => 'mysql',
  db_password => 's0m4r4nd0mp4ssw0rd',
}
```

To use PostgreSQL set `backend` to `postgresql`.

```puppet
class { 'powerdns':
  backend     => 'postgresql',
  db_password => 's0m4r4nd0mp4ssw0rd',
}
```

To use Bind you must set `backend_install` and `backend_create_tables` to
false. For example:

```puppet
class { 'powerdns':
  backend               => 'bind',
  backend_install       => false,
  backend_create_tables => false,
}
```

To use LDAP you must set `backend_install` and `backend_create_tables` to
false. For example:

```puppet
class { 'powerdns':
  backend               => 'ldap',
  backend_install       => false,
  backend_create_tables => false,
}
```

To use SQLite you must set `backend` to `sqlite`. Ensure that the `pdns` user
has write permissions to directory holding database file. For example:

```puppet
class { 'powerdns':
  backend => 'sqlite',
  db_file => '/opt/powerdns.sqlite3',
}
```

To use lmdb you must set `backend_install` and `backend_create_tables` to
false. For example:

```puppet
class { 'powerdns':
  backend               => 'lmdb',
  backend_install       => false,
  backend_create_tables => false,
}
```

### Manage zones with this module

With this module you can manage zones if you use a backend that is capable of doing so (eg. sqllite, postgres or mysql).

You can add a zone 'example.org' by using:

``` puppet
 powerdns_zone{'example.org': }
```

This will add the zone which is then managed through puppet any records not added
through puppet will be deleted additionaly a SOA record is generated. To just ensure the
zone is available, but not manage any records use (and do not add any powerdns\_record
resources with target this domain):

``` puppet
 powerdns_zone{'example.org':
   manage_records => false,
 }
```

To addjust the SOA record (if add\_soa is set to true), use the soa\_\* parameters documented in the powerdns\_record resource.

The zone records can be managed through the powerdns\_record resource. As an example we add a NS an A and an AAAA record:

``` puppet
 powerdns_record{'nameserver1':
   target_zone => 'example.org',
   rname       => '.',  # a dot takes the target_zone only as rname
   rtype       => 'NS',
   rttl        => '4242',
   rcontent    => 'ns1.example.org.' # pay attention to the dot at the end !
 }
 powerdns_record{'ns1.example.org':
   rcontent => '127.0.0.1',
 }
 powerdns_record{'ipv6-ns1.example.org':
   target_zone => 'example.org',
   rname       => 'ns1',  # for the full record, the target_zone will be amended
   rtype       => 'AAAA',
   rcontent    => '::1',
 }
 powerdns_record{'www-server':
   target_zone => 'example.org',
   rname       => 'www',
   rcontent    => '127.0.0.1'
 }
```

Remark: if the target\_zone is not managed with powerdns\_zone resource, powerdns\_record does not change anything!

### Manage autoprimaries (automatic provisioning of secondaries)

It's possible to manage the the 'autoprimaries' with puppet (For a decription of the autoprimary functionality in
powerdns see [powerdns manual](https://doc.powerdns.com/authoritative/modes-of-operation.html#autoprimary-automatic-provisioning-of-secondaries).
The autoprimaries are set with the powerdns\_autoprimary resource. As an example we add the primary 1.2.3.4 named ns1.example.org whith the account 'test'

``` yaml
powerdns_autoprimary{'1.2.3.4@ns1.example.org':
  ensure  => 'present',
  account => 'test',
}
```

As an alternative, you can set the autoprimaries parameter of the powerdns class to achive the same (eg. if you use hiera).

For removal of an autoprimary set ensure to 'absent' or set the parameter purge\_autoprimaries of the powerdns class to true which willa
remove all autoprimaries that are not present in the puppet manifest.

### Manage settings

All PowerDNS settings can be managed with `powerdns::config`. Depending on the
backend we will set a few configuration settings by default. All other
variables can be changed as follows:

```puppet
powerdns::config { 'api':
  ensure  => present,
  setting => 'api',
  value   => 'yes',
  type    => 'authoritative',
}
```

### Hiera

This module supports Hiera and uses create_resources to configure PowerDNS
if you want to. An example can be found below:

```puppet
powerdns::db_root_password: 's0m4r4nd0mp4ssw0rd'
powerdns::db_username: 'powerdns'
powerdns::db_password: 's0m4r4nd0mp4ssw0rd'
powerdns::recursor: true
powerdns::recursor::package_ensure: 'latest'
powerdns::authoritative::package_ensure: 'latest'

powerdns::auth::config:
  gmysql-dnssec:
    value: ''
  local-address:
    value: '127.0.0.1'
  api:
    value: 'yes'
```

#### Prevent duplicate declaration

In this example we configure `local-address` to `127.0.0.1`. If you also
run a recursor on the same server and you would like to configure
`local-address` via Hiera you need to set `setting` and change the name of
the parameter in Hiera to a unique value.

For example:

```puppet
powerdns::auth::config:
  local-address-auth:
    setting: 'local-address'
    value: '127.0.0.1'
powerdns::recursor::config:
  local-address-recursor:
    setting: 'local-address'
    value: '127.0.0.2'
```

If you have other settings that share the same name between the recursor and
authoritative server you would have to use the same approach to prevent
duplicate declaration errors.

## Development

We strongly believe in the power of open source. This module is our way
of saying thanks.

If you want to contribute please:

1. Fork the repository.
2. Run tests. It's always good to know that you can start with a clean slate.
3. Add a test for your change.
4. Make sure it passes.
5. Push to your fork and submit a pull request to the `main` branch.

We can only accept pull requests with passing tests.

To install all of its dependencies please run:

```bash
bundle install --path vendor/bundle --without development
```

### Running unit tests

```bash
bundle exec rake test
```

### Running acceptance tests

The unit tests only verify if the code runs, not if it does exactly
what we want on a real machine. For this we use Beaker. Beaker will
start a new virtual machine (using Vagrant) and runs a series of
simple tests.

You can run Beaker tests with:

```bash
bundle exec rake spec_prep
BEAKER_destroy=onpass bundle exec rake beaker:centos7
BEAKER_destroy=onpass bundle exec rake beaker:oel7
BEAKER_destroy=onpass bundle exec rake beaker:ubuntu1804
BEAKER_destroy=onpass bundle exec rake beaker:debian10
```

We recommend specifying `BEAKER_destroy=onpass` as it will keep the
Vagrant machine running in case something fails.
