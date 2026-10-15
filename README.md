# ir_agent

This module is provided for deploying and configuring Rapid7 Insight Agent on
Red Hat Enterprise Linux (and clones).

## Table of Contents

- [ir\_agent](#ir_agent)
  - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Setup](#setup)
    - [Setup Requirements](#setup-requirements)
    - [Beginning with ir\_agent](#beginning-with-ir_agent)
  - [Usage](#usage)
  - [Limitations](#limitations)
    - [Auditd Compatibility Mode](#auditd-compatibility-mode)

## Description

This module can be used to install, configure, and remove Rapid7 Insight Agent.
Configurable options include proxy settings and enabling and disabling auditd
compatibility mode.

## Setup

### Setup Requirements

This module requires (but does not include) the agent package (EL8+) or install
script (EL7 and lower) from Rapid7. The package should be available from a
configured YUM repository. You will also need an installation token from Rapid7
to download the required certificates during installation.

### Beginning with ir_agent

A basic usage of the class.

```puppet
class { '::ir_agent':
  source => 'puppet:///modules/test/agent_installer_x64.sh',
  token  => 'us:01234567-89ab-cdef-0123-4567890abcde',
}
```

## Usage

In most cases the basic usage is sufficient. For other cases, using a proxy and
enabling auditd compatibility mode might be necessary.

```puppet
class { '::ir_agent':
  source                    => 'puppet:///modules/test/agent_installer_x64.sh',
  token                     => 'us:01234567-89ab-cdef-0123-4567890abcde',
  auditd_compatibility_mode => true,
  https_proxy               => 'proxy.example.org:3128',
}
```

## Limitations

If this module is used to install the Insight agent, it will install the audit
package because it is a requirement for the Insight agent unless the
manage_audit_package attribute is set to false. If this module is later used to
remove the Insight agent, it will not remove the audit package and it will
enable and start the auditd service (if it was stopped and disabled) unless the
manage_auditd attribute is set to false. The audit package can then be removed
and this module will not reinstall the audit package as long as ensure is set
to absent.

On EL8 and newer, the af_unix audit plugin used in auditd compatibility mode is
shipped in the audispd-plugins package. If manage_audit_package is set to false
while manage_auditd is true, that package must be installed by other means,
otherwise auditd cannot start the plugin and Insight Agent receives no events.

### Auditd Compatibility Mode

If the manage_auditd attribute is set to false and auditd_compatibility_mode is
set to true, this module will not manage auditd in any way. It is important that
auditd is properly configured to support Insight Agent in auditd compatibility
mode.

On EL8 and newer, the af_unix audit plugin is configured to send events to the
socket in string format, as recommended by Rapid7 because of an issue
introduced in audit 3.1.1 that corrupts events in binary format. This requires
Insight Agent newer than 4.0.8.

On EL9, the configuration targets audit 3.1.5-4 and newer (EL9.6+). Since that
version, the af_unix plugin expects binary input from auditd (`format =
binary`) and takes the socket output format as third argument; with `format =
string` it silently drops every event (RHEL-248251). Older EL9 minor releases
(9.0 to 9.5) ship a plugin that passes events through unchanged and only
accepts the socket mode and path: with the default configuration it ignores
the third argument and outputs binary events. For those nodes, use the same
configuration as EL8 in Hiera:

```yaml
ir_agent::audisp::af_unix::args: '0600 /var/run/audispd_events'
ir_agent::audisp::af_unix::format: 'string'
```

https://docs.rapid7.com/insight-agent/auditd-compatibility-mode-for-linux-assets/
