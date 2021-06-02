# @summary Module for installing and managing Rapid7 Insight Agent.
#
# @param ensure
#   If `present`, installs the agent. If `absent`, uninstalls the agent.
#   The agent is self-updating, so there is no `latest` option provided.
#
# @param source
#   Source location for the agent installer script.
#
# @param token
#   Token needed to download the certificates needed to enable the agent.
#
# @param home
#   Rapid7 installation home.
#
# @param auditd_compatibility_mode
#   Run the agent in auditd compatibility mode.
#
# @param proxy_host
#   Proxy host to use for communicating with Rapid7 cloud.
#
# @param proxy_port
#   Proxy port to use for communicating with Rapid7 cloud.
#
# @example Deploy the agent with default options.
#
#   class { 'ir_agent':
#     source => 'puppet:///modules/my_module/agent_installer_x64.sh',
#     token  => 'us:01234567-89ab-cdef-0123-4567890abcde',
#   }
#
class ir_agent (
  Enum['present', 'absent'] $ensure = 'present',
  Optional[String] $source = undef,
  Optional[String] $token = undef,
  Stdlib::Unixpath $home = '/opt/rapid7',
  Boolean $auditd_compatibility_mode = false,
  Optional[String] $proxy_host = undef,
  Optional[Stdlib::Port] $proxy_port = undef,
) {

  $agent_installer = "${home}/agent_installer_x64.sh"

  if $ensure == 'present' {

    if ! $source or ! $token {
      fail('Parameters source and token are required.')
    }

    package { 'audit': ensure => installed }

    # Create home.
    #
    file { $home:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Download the installer.
    #
    file { $agent_installer:
      ensure => file,
      source => $source,
      owner  => 'root',
      group  => 'root',
      mode   => '0750',
    }

    # Generate the install command.
    #
    if $proxy_host and $proxy_port  {
      $agent_install_cmd = @("CMD"/L)
        ${agent_installer} install_start --token ${token} \
        --https-proxy ${proxy_host}:${proxy_port}
        |-CMD
    } else {
      $agent_install_cmd = @("CMD")
        ${agent_installer} install_start --token ${token}
        |-CMD
    }

    # Install the agent.
    #
    exec { 'install_insight_agent':
      command => $agent_install_cmd,
      creates => "${home}/ir_agent/ir_agent",
      require => File[$agent_installer],
    }

    # Configure the agent for proxy if specified.
    #
    if $proxy_host and $proxy_port {
      file { "${home}/ir_agent/components/bootstrap/common/proxy.config":
        ensure  => file,
        content => "{\"https\": \"${proxy_host}:${proxy_port}\"}\n",
        owner   => 'root',
        group   => 'root',
        mode    => '0700',
        notify  => Service['ir_agent'],
      }
    } else {
      file { "${home}/ir_agent/components/bootstrap/common/proxy.config":
        ensure => absent,
        notify => Service['ir_agent'],
      }
    }

    # Add systemd dropin to make sure agent starts after all local file systems.
    #
    if $facts['service_provider'] == 'systemd' {
      if defined('systemd::service::dropin') {
        systemd::service::dropin { 'ir_agent':
          requires    => ['local-fs.target'],
          after_units => ['local-fs.target'],
          require     => Exec['install_insight_agent'],
        }
      } elsif defined('systemd::dropin_file') {
        systemd::dropin_file { '99-override.conf':
          unit    => 'ir_agent.service',
          source  => "puppet:///modules/${module_name}/ir_agent_dropin.conf",
          require => Exec['install_insight_agent'],
        }
      }
    }

    # Determine path to audit rules based on OS major release.
    #
    if $facts.get('os.release.major') == '6' {
      $audit_rules = '/etc/audit/audit.rules'
    } else {
      $audit_rules = '/etc/audit/rules.d/audit.rules'
    }

    # Backup the audit rules.
    #
    file { 'audit_rules_backup':
      ensure  => file,
      path    => "${audit_rules}.bak",
      source  => $audit_rules,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      replace => false,
      require => Package['audit'],
    }

    # Disable auditd or enable for compatibility mode.
    #
    if $auditd_compatibility_mode {

      exec { 'stop_insight_agent':
        command => '/sbin/service ir_agent  stop',
        unless  => "/usr/bin/test -f ${home}/ir_agent/components/insight_agent/common/audit.conf",
        require => Exec['install_insight_agent'],
      }

      file { $audit_rules:
        ensure  => file,
        source  => "puppet:///modules/${module_name}/audit.rules",
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => File['audit_rules_backup'],
        notify  => Service['auditd'],
      }

      file { '/etc/audisp/plugins.d/af_unix.conf':
        ensure  => file,
        source  => "puppet:///modules/${module_name}/af_unix.conf",
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        require => Package['audit'],
        notify  => Service['auditd'],
      }

      file_line { 'audispd.conf':
        ensure  => present,
        path    => '/etc/audisp/audispd.conf',
        line    => 'q_depth = 8192',
        match   => '^q_depth =',
        require => Package['audit'],
        notify  => Service['auditd'],
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

    } else {

      service { 'auditd':
        ensure  => stopped,
        enable  => if $facts['service_provider'] == 'systemd' { 'mask' } else { 'false' },
        stop    => '/sbin/service auditd stop',
        require => Package['audit'],
        notify  => Service['ir_agent'],
      }

      file { $audit_rules:
        ensure  => file,
        source  => getparam(File['audit_rules_backup'], 'path'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => File['audit_rules_backup'],
      }

      file_line { 'af_unix.conf':
        ensure  => present,
        path    => '/etc/audisp/plugins.d/af_unix.conf',
        line    => 'active = no',
        match   => '^active =',
        require => Package['audit'],
      }

      file { "${home}/ir_agent/components/insight_agent/common/audit.conf":
        ensure  => absent,
        require => Exec['install_insight_agent'],
        notify  => Service['ir_agent'],
      }

    }

    # Ensure Insight agent is running.
    #
    service { 'ir_agent':
      ensure  => running,
      enable  => true,
      require => Exec['install_insight_agent'],
    }

  } else {

    # Uninstall Insight Agent.
    #
    exec { 'uninstall_insight_agent':
      command => "${agent_installer} uninstall",
      onlyif  => "/usr/bin/test -x ${agent_installer}",
    }

    file { $home:
      ensure  => absent,
      force   => true,
      require => Exec['uninstall_insight_agent'],
    }

    # Reset auditd to original settings and restart.
    #
    file { $audit_rules:
      ensure  => file,
      source  => getparam(File['audit_rules_backup'], 'path'),
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File['audit_rules_backup'],
      notify  => Service['auditd'],
    }

    file_line { 'af_unix.conf':
      ensure  => present,
      path    => '/etc/audisp/plugins.d/af_unix.conf',
      line    => 'active = no',
      match   => '^active =',
      require => Package['audit'],
      notify  => Service['auditd'],
    }

    service { 'auditd':
      ensure  => running,
      enable  => true,
      restart => '/sbin/service auditd restart',
      require => [
        Package['audit'],
        Exec['uninstall_insight_agent'],
      ],
    }

  }

}
