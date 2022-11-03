# @summary Install Goatcounter server
#
# @param hostname is the hostname for the goat server
# @param tls_account is the account details for requesting the TLS cert
# @param admin_email is the email address to access metrics
# @param admin_password is the password to access metrics
# @param tls_challengealias is the domain to use for TLS cert validation
# @param version sets the goatcounter version to use
# @param backup_target sets the target repo for backups
# @param backup_watchdog sets the watchdog URL to confirm backups are working
# @param backup_password sets the encryption key for backup snapshots
# @param backup_environment sets the env vars to use for backups
class goat (
  String $hostname,
  String $tls_account,
  String $admin_email,
  String $admin_password,
  Optional[String] $tls_challengealias = undef,
  String $version = 'v2.2.3',
  Optional[String] $backup_target = undef,
  Optional[String] $backup_watchdog = undef,
  Optional[String] $backup_password = undef,
  Optional[Hash[String, String]] $backup_environment = undef,
) {
  $arch = $facts['os']['architecture'] ? {
    'x86_64'  => 'amd64',
    'arm64'   => 'arm64',
    'aarch64' => 'arm64',
    'arm'     => 'arm',
    default   => 'error',
  }

  $binfile = '/usr/local/bin/goatcounter'
  $filename = "goatcounter-dev-linux-${arch}.gz"
  $url = "https://github.com/arp242/goatcounter/releases/download/${version}/${filename}"

  $dbdir = '/var/lib/goatcounter'
  $dbfile = "${dbdir}/goatcounter.sqlite3"
  $dburl = "sqlite+${dbfile}"
  $dbcmd = "${binfile} db create site -createdb \
  -vhost ${hostname} -user.email ${admin_email} -user.password ${admin_password} -db ${dburl}"

  group { 'goatcounter':
    ensure => present,
    system => true,
  }

  user { 'goatcounter':
    ensure => present,
    system => true,
    gid    => 'goatcounter',
    shell  => '/usr/bin/nologin',
    home   => '/var/lib/goatcounter',
  }

  exec { 'download goatcounter':
    command => "/usr/bin/curl -sL '${url}' | gunzip > ${binfile} && chmod a+x ${binfile}",
    unless  => '/usr/local/bin/goatcounter version | grep version=dev',
  }

  -> file { [$dbdir, '/var/log/goatcounter']:
    ensure => directory,
    owner  => 'goatcounter',
    group  => 'goatcounter',
  }

  -> exec { $dbcmd:
    user    => 'goatcounter',
    creates => $dbfile,
  }

  -> file { '/etc/systemd/system/goatcounter.service':
    ensure => file,
    source => 'puppet:///modules/goat/goatcounter.service',
  }

  ~> service { 'goatcounter':
    ensure => running,
    enable => true,
  }

  nginx::site { $hostname:
    proxy_target       => 'http://localhost:8081',
    tls_challengealias => $tls_challengealias,
    tls_account        => $tls_account,
  }

  if $backup_target != '' {
    backup::repo { 'goat':
      source       => $dbdir,
      target       => $backup_target,
      watchdog_url => $backup_watchdog,
      password     => $backup_password,
      environment  => $backup_environment,
    }
  }
}
