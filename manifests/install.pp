# @summary Class for installing the Insight agent.
#
# @api private
#
class ir_agent::install {
  $source = $ir_agent::source
  $token = $ir_agent::token
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

  file { $agent_installer:
    ensure => file,
    source => $source,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  if $https_proxy  {
    $_agent_install_cmd = @("CMD"/L)
      ${agent_installer} install_start --token ${token} \
      --https-proxy ${https_proxy}
      |-CMD
  } else {
    $_agent_install_cmd = @("CMD")
      ${agent_installer} install_start --token ${token}
      |-CMD
  }

  exec { 'install_insight_agent':
    command => $_agent_install_cmd,
    creates => "${home}/ir_agent/ir_agent",
    require => File[$agent_installer],
  }

  if $https_proxy {
    file { "${home}/ir_agent/components/bootstrap/common/proxy.config":
      ensure  => file,
      content => "{\"https\": \"${https_proxy}\"}\n",
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

  service { 'ir_agent':
    ensure  => running,
    enable  => true,
    require => Exec['install_insight_agent'],
  }

}
