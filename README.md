# ir_agent

This module is provided for deploying and configuring Rapid7 Insight Agent on
Red Hat Enterprise Linux (and clones).

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with ir_agent](#beginning-with-rapid7)
1. [Usage](#usage)
1. [Limitations](#limitations)

## Description

This module can be used to install, configure, and remove Rapid7 Insight Agent.
Configurable options include proxy settings and enabling and disabling auditd
compatibility mode. Plans are also available for deploying Insight Agent using
Bolt.

## Setup

### Setup Requirements

This module requires (and does not include) the agent installer script from
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
  proxy_host                => 'proxy.example.org',
  proxy_port                => 3128,
}
```

## Limitations

This module has been tested only on RHEL 6 and 7 clones.
