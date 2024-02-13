# @summary Module for installing and managing Rapid7 Insight Agent.
#
# @param ensure
#   If `present`, installs the agent. If `absent`, uninstalls the agent.
#   The agent is self-updating, so there is no `latest` option provided.
#
# @param source
#   Source location for the agent installer script.
#
# @param checksum
#  Checksum for the agent installer script source file.
#
# @param checksum_type
#  Checksum type for the source_checksum.
#
# @param token
#   Token needed to download the certificates needed to enable the agent.
#
# @param semantic_version
#   Reinstall the agent if the current semantic version is less than this
#   version. The agent will never be reinstalled if this is not set.
#
# @param auditd_compatibility_mode
#   Run the agent in auditd compatibility mode.
#
# @param manage_auditd
#   Manage the auditd configuration. This is ignored if
#   auditd_compatibility_mode is false.
#
# @param https_proxy
#   Proxy host and port to use for communicating with Rapid7 cloud.
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
  Optional[String] $checksum = undef,
  Optional[Enum['md5', 'sha256', 'sha224', 'sha384', 'sha512']] $checksum_type = undef,
  Optional[String] $token = undef,
  Optional[String] $semantic_version = undef,
  Boolean $auditd_compatibility_mode = false,
  Boolean $manage_auditd = true,
  Optional[String] $https_proxy = undef,
) {
  unless $facts.get('os.family') == 'RedHat' and $facts.get('os.release.major') in ['6', '7', '8', '9'] {
    fail('unsupported operating system')
  }

  $home = '/opt/rapid7'
  $agent_installer = "${home}/agent_installer_x64.sh"
  $audit_package = lookup('ir_agent::audit::package', String)
  $audit_rules = lookup('ir_agent::audit::rules', Stdlib::Unixpath)
  $audit_start_cmd = lookup('ir_agent::audit::start_cmd', String)
  $audispd_conf = lookup('ir_agent::audispd::conf', Stdlib::Unixpath)
  $audisp_plugins_dir = lookup('ir_agent::audisp::plugins_dir', Stdlib::Unixpath)

  if $ensure == 'present' {
    contain ir_agent::audit
    contain ir_agent::install
  } else {
    contain ir_agent::uninstall
  }
}
