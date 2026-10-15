# @summary Class for configuring audit service for Insight agent.
#
# @api private
#
class ir_agent::audit {
  $installer = $ir_agent::installer
  $package = $ir_agent::package
  $home = $ir_agent::home
  $auditd_compatibility_mode = $ir_agent::auditd_compatibility_mode
  $manage_auditd = $ir_agent::manage_auditd
  $manage_audit_package = $ir_agent::manage_audit_package
  $audit_package = $ir_agent::audit_package
  $audit_rules = $ir_agent::audit_rules
  $audispd_conf = $ir_agent::audispd_conf
  $audisp_plugins_dir = $ir_agent::audisp_plugins_dir
  $audisp_plugins_package = $ir_agent::audisp_plugins_package

  if $installer == 'package' {
    $_install_insight_agent = Package[$package]
  } else {
    $_install_insight_agent = Exec['install_insight_agent']
  }

  if $manage_audit_package and !defined(Package[$audit_package]) {
    package { 'audit':
      ensure => installed,
      name   => $audit_package,
    }
    $_auditd_package = Package['audit']
  } else {
    $_auditd_package = undef
  }

  if $auditd_compatibility_mode {
    exec { 'stop_insight_agent':
      command => '/sbin/service ir_agent  stop',
      unless  => "/usr/bin/test -f ${home}/ir_agent/components/insight_agent/common/audit.conf",
      require => $_install_insight_agent,
    }

    if $manage_auditd {
      # The af_unix plugin is a standalone program shipped in a separate
      # package since audit 3.0.
      if $manage_audit_package and $audisp_plugins_package and !defined(Package[$audisp_plugins_package]) {
        package { 'audispd-plugins':
          ensure  => installed,
          name    => $audisp_plugins_package,
          require => $_auditd_package,
        }
        $_audisp_plugins_package = Package['audispd-plugins']
      } elsif $audisp_plugins_package and defined(Package[$audisp_plugins_package]) {
        # Declared elsewhere: still order the plugin configuration after it.
        $_audisp_plugins_package = Package[$audisp_plugins_package]
      } else {
        $_audisp_plugins_package = undef
      }

      file { $audit_rules:
        ensure  => file,
        source  => "puppet:///modules/${module_name}/audit.rules",
        backup  => '.puppet-bak',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => $_auditd_package,
        notify  => Service['auditd'],
      }

      # audit 2.x (EL6/EL7) uses the builtin plugin: keep the historical file
      # unchanged so existing nodes are not modified nor auditd restarted.
      if $ir_agent::af_unix_type == 'builtin' {
        $_af_unix_conf = { 'source' => "puppet:///modules/${module_name}/af_unix.conf" }
      } else {
        $_af_unix_conf = {
          'content' => epp("${module_name}/af_unix.conf.epp", {
            'path'   => $ir_agent::af_unix_path,
            'type'   => $ir_agent::af_unix_type,
            'args'   => $ir_agent::af_unix_args,
            'format' => $ir_agent::af_unix_format,
          }),
        }
      }

      # Back up the original configuration only once, for uninstall: the
      # file backup would replace it on every content change.
      exec { 'backup_af_unix_conf':
        command => "cp -p ${audisp_plugins_dir}/af_unix.conf ${audisp_plugins_dir}/af_unix.conf.puppet-bak",
        creates => "${audisp_plugins_dir}/af_unix.conf.puppet-bak",
        onlyif  => "test -f ${audisp_plugins_dir}/af_unix.conf",
        path    => ['/bin', '/usr/bin'],
        require => [$_auditd_package, $_audisp_plugins_package],
        before  => File["${audisp_plugins_dir}/af_unix.conf"],
      }

      file { "${audisp_plugins_dir}/af_unix.conf":
        ensure  => file,
        backup  => false,
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        require => [$_auditd_package, $_audisp_plugins_package],
        notify  => Service['auditd'],
        *       => $_af_unix_conf,
      }

      file_line { 'audispd.conf':
        ensure  => present,
        path    => $audispd_conf,
        line    => 'q_depth = 8192',
        match   => '^q_depth =',
        require => $_auditd_package,
        notify  => Service['auditd'],
      }

      service { 'auditd':
        ensure  => running,
        enable  => true,
        restart => '/sbin/service auditd restart',
        require => [
          $_auditd_package,
          Exec['stop_insight_agent'],
        ],
        notify  => Service['ir_agent'],
      }
    }

    file { "${home}/ir_agent/components/insight_agent/common/audit.conf":
      ensure  => file,
      content => '{"auditd-compatibility-mode":true}',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => $_install_insight_agent,
      notify  => Service['ir_agent'],
    }
  } else {
    service { 'auditd':
      ensure  => stopped,
      enable  => if $facts['service_provider'] == 'systemd' { 'mask' } else { 'false' },
      stop    => '/sbin/service auditd stop',
      require => $_auditd_package,
      notify  => Service['ir_agent'],
    }

    file { "${home}/ir_agent/components/insight_agent/common/audit.conf":
      ensure  => absent,
      require => $_install_insight_agent,
      notify  => Service['ir_agent'],
    }
  }
}
