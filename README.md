# ir_agent

This module is provided for deploying and configuring Rapid7 Insight Agent on
Red Hat Enterprise Linux (and clones).

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
   - [Setup requirements](#setup-requirements)
   - [Beginning with ir_agent](#beginning-with-rapid7)
1. [Usage](#usage)
1. [Limitations](#limitations)

## Description

This module can be used to install, configure, and remove Rapid7 Insight Agent.
Configurable options include proxy settings and enabling and disabling auditd
compatibility mode.

## Setup

### Setup Requirements

This module requires (but does not include) the agent installer script from
Rapid7. You will also need an installation token from Rapid7 to download the
required certificates during installation.

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
package because it is a requirement for the Insight agent. If this module is
later used to remove the Insight agent, it will not remove the audit package and
it will enable and start the auditd service (if it was stopped and disabled)
unless the manage_auditd attribute is set to false. The audit package can then
be removed and this module will not reinstall the audit package as long as
ensure => absent.

### Auditd Compatibility Mode

If the manage_auditd attribute is set to false and auditd_compatibility_mode is
set to true, this module will not manage auditd in any way. It is important that
auditd is properly configured to support Insight Agent in auditd compatibility
mode.

https://docs.rapid7.com/insight-agent/auditd-compatibility-mode-for-linux-assets/
