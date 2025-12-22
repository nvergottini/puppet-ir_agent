# @summary Class for installing the Insight agent.
#
# @api private
#
class ir_agent::install {
  $installer = $ir_agent::installer
  $package = $ir_agent::package
  $source = $ir_agent::source
  $checksum = $ir_agent::checksum
  $checksum_type = $ir_agent::checksum_type
  $token = $ir_agent::token
  $semantic_version = $ir_agent::semantic_version
  $home = $ir_agent::home
  $auditd_compatibility_mode = $ir_agent::auditd_compatibility_mode
  $https_proxy = $ir_agent::https_proxy
  $agent_installer = $ir_agent::agent_installer

  $_install_args = $https_proxy ? {
    String  => "--token ${token} --https-proxy ${https_proxy}",
    default => "--token ${token}",
  }

  if $installer == 'package' {
    package { $package:
      ensure => installed,
    }

    unless $facts.get('ir_agent.client_id') {
      $_configure_insight_agent = @("EOF"/$)
        cd ${home}/ir_agent/components/insight_agent/\$(rpm -q --qf "%{VERSION}" ${package})/
        ./configure_agent.sh ${_install_args} -v --start
        |-EOF

      exec { 'configure_insight_agent':
        command  => $_configure_insight_agent,
        provider => 'shell',
        require  => Package[$package],
        before   => File['insight_agent_proxy_config'],
      }
    }
  } else {
    file { $home:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    file { 'insight_agent_installer':
      ensure         => file,
      path           => $agent_installer,
      source         => $source,
      checksum       => $checksum_type,
      checksum_value => $checksum,
      owner          => 'root',
      group          => 'root',
      mode           => '0750',
    }

    $_current_version = $facts.get('ir_agent.semantic_version')

    if $semantic_version =~ String and $_current_version =~ String and versioncmp($_current_version, $semantic_version) < 0 {
      exec { 'install_insight_agent':
        command => "${agent_installer} reinstall_start ${_install_args}",
        require => File['insight_agent_installer'],
        before  => File['insight_agent_proxy_config'],
      }
    } else {
      exec { 'install_insight_agent':
        command => "${agent_installer} install_start ${_install_args}",
        creates => "${home}/ir_agent/ir_agent",
        require => File['insight_agent_installer'],
        before  => File['insight_agent_proxy_config'],
      }
    }
  }

  if $https_proxy {
    file { 'insight_agent_proxy_config':
      ensure  => file,
      path    => "${home}/ir_agent/components/bootstrap/common/proxy.config",
      content => "{\"https\": \"${https_proxy}\"}\n",
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      notify  => Service['ir_agent'],
    }
  } else {
    file { 'insight_agent_proxy_config':
      ensure => absent,
      path   => "${home}/ir_agent/components/bootstrap/common/proxy.config",
      notify => Service['ir_agent'],
    }
  }

  service { 'ir_agent':
    ensure => running,
    enable => true,
  }
}
