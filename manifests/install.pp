# @summary Class for installing the Insight agent.
#
# @api private
#
class ir_agent::install {
  $source = $ir_agent::source
  $checksum = $ir_agent::checksum
  $checksum_type = $ir_agent::checksum_type
  $token = $ir_agent::token
  $semantic_version = $ir_agent::semantic_version
  $home = $ir_agent::home
  $auditd_compatibility_mode = $ir_agent::auditd_compatibility_mode
  $https_proxy = $ir_agent::https_proxy
  $agent_installer = $ir_agent::agent_installer

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

  $_install_args = $https_proxy ? {
    String  => "--token ${token} --https-proxy ${https_proxy}",
    default => "--token ${token}",
  }

  $_current_version = $facts.get('ir_agent.semantic_version')

  if $semantic_version =~ String and $_current_version =~ String and versioncmp($_current_version, $semantic_version) < 0 {
    exec { 'install_insight_agent':
      command => "${agent_installer} reinstall_start ${_install_args}",
      require => File['insight_agent_installer'],
    }
  } else {
    exec { 'install_insight_agent':
      command => "${agent_installer} install_start ${_install_args}",
      creates => "${home}/ir_agent/ir_agent",
      require => File['insight_agent_installer'],
    }
  }

  if $https_proxy {
    file { "${home}/ir_agent/components/bootstrap/common/proxy.config":
      ensure  => file,
      content => "{\"https\": \"${https_proxy}\"}\n",
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Exec['install_insight_agent'],
      notify  => Service['ir_agent'],
    }
  } else {
    file { "${home}/ir_agent/components/bootstrap/common/proxy.config":
      ensure  => absent,
      require => Exec['install_insight_agent'],
      notify  => Service['ir_agent'],
    }
  }

  service { 'ir_agent':
    ensure  => running,
    enable  => true,
    require => Exec['install_insight_agent'],
  }
}
