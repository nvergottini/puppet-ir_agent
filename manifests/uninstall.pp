# @summary Class for uninstalling the Insight agent.
#
# @api private
#
class ir_agent::uninstall {
  $installer = $ir_agent::installer
  $package = $ir_agent::package
  $home = $ir_agent::home
  $agent_installer = $ir_agent::agent_installer
  $manage_auditd = $ir_agent::manage_auditd
  $audit_rules = $ir_agent::audit_rules
  $audit_start_cmd = $ir_agent::audit_start_cmd
  $audisp_plugins_dir = $ir_agent::audisp_plugins_dir

  if $installer == 'package' {
    package { $package:
      ensure => absent,
    }
    $_uninstall_insight_agent = Package[$package]
  } else {
    exec { 'uninstall_insight_agent':
      command => "${agent_installer} uninstall",
      onlyif  => "/usr/bin/test -x ${agent_installer}",
    }
    $_uninstall_insight_agent = Exec['uninstall_insight_agent']
  }

  file { $home:
    ensure  => absent,
    force   => true,
    require => $_uninstall_insight_agent,
  }

  if $manage_auditd {
    exec {
      default:
        refreshonly => true,
        provider    => 'shell',
        subscribe   => $_uninstall_insight_agent,
        ;
      'restore_audit_rules':
        command => "mv ${audit_rules}.puppet-bak ${audit_rules}",
        onlyif  => "test -f ${audit_rules}.puppet-bak",
        ;
      'restore_af_unix_conf':
        command => "mv ${audisp_plugins_dir}/af_unix.conf.puppet-bak ${audisp_plugins_dir}/af_unix.conf",
        onlyif  => "test -f ${audisp_plugins_dir}/af_unix.conf.puppet-bak",
        ;
      'start_auditd':
        command => $audit_start_cmd,
        ;
    }
  }
}
