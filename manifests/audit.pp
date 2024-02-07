# @summary Class for configuring audit service for Insight agent.
#
# @api private
#
class ir_agent::audit {
  $home = $ir_agent::home
  $auditd_compatibility_mode = $ir_agent::auditd_compatibility_mode
  $manage_auditd = $ir_agent::manage_auditd
  $audit_package = $ir_agent::audit_package
  $audit_rules = $ir_agent::audit_rules
  $audispd_conf = $ir_agent::audispd_conf
  $audisp_plugins_dir = $ir_agent::audisp_plugins_dir

  package { 'audit':
    ensure => installed,
    name   => $audit_package,
  }

  if $auditd_compatibility_mode {
    exec { 'stop_insight_agent':
      command => '/sbin/service ir_agent  stop',
      unless  => "/usr/bin/test -f ${home}/ir_agent/components/insight_agent/common/audit.conf",
      require => Exec['install_insight_agent'],
    }

    if $manage_auditd {
      file { $audit_rules:
        ensure  => file,
        source  => "puppet:///modules/${module_name}/audit.rules",
        backup  => '.puppet-bak',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => Package['audit'],
        notify  => Service['auditd'],
      }

      file { "${audisp_plugins_dir}/af_unix.conf":
        ensure  => file,
        source  => "puppet:///modules/${module_name}/af_unix.conf",
        backup  => '.puppet-bak',
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        require => Package['audit'],
        notify  => Service['auditd'],
      }

      file_line { 'audispd.conf':
        ensure  => present,
        path    => $audispd_conf,
        line    => 'q_depth = 8192',
        match   => '^q_depth =',
        require => Package['audit'],
        notify  => Service['auditd'],
      }

      service { 'auditd':
        ensure  => running,
        enable  => true,
        restart => '/sbin/service auditd restart',
        require => [
          Package['audit'],
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
      require => Exec['install_insight_agent'],
      notify  => Service['ir_agent'],
    }
  } else {
    service { 'auditd':
      ensure  => stopped,
      enable  => if $facts['service_provider'] == 'systemd' { 'mask' } else { 'false' },
      stop    => '/sbin/service auditd stop',
      require => Package['audit'],
      notify  => Service['ir_agent'],
    }

    file { "${home}/ir_agent/components/insight_agent/common/audit.conf":
      ensure  => absent,
      require => Exec['install_insight_agent'],
      notify  => Service['ir_agent'],
    }
  }
}
