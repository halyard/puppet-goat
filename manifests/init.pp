# @summary Install Goatcounter server
#
# @param hostname is the hostname for the goat server
# @param tls_account is the account details for requesting the TLS cert
# @param admin_password is the password to access metrics
# @param tls_challengealias is the domain to use for TLS cert validation
# @param version sets the goatcounter version to use
class goat (
  String $hostname,
  String $tls_account,
  String $admin_password,
  Optional[String] $tls_challengealias = undef,
  String $version = 'v2.2.3',
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

  exec { 'download goatcounter':
    command => "curl -sL '${url}' | gunzip > ${binfile} && chmod a+x ${binfile}",
    unless  => '/usr/local/bin/goatcounter version | grep version=dev',
  }

  -> file { '/var/lib/goatcounter':
    ensure => directory,
  }

  -> exec { "${binfile} db create site -createdb -vhost ${hostname} -user.email ${admin_email} -user.password ${admin_password} -db sqlite+/var/lib/goatcounter/goatcounter.sqlite3":
    creates => '/var/lib/goatcounter/goatcounter.sqlite3',
  }

  -> file { '/etc/systemd/system/goatcounter.service':
    ensure => file,
    source => 'puppet:///modules/goat/goatcounter.service',
  }

  ~> service { 'goatcounter':
    ensure  => running,
    enable  => true,
  }

  nginx::site { $hostname:
    proxy_target       => 'http://localhost:8081',
    tls_challengealias => $tls_challengealias,
    tls_account        => $tls_account,
  }
}
