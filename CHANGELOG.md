# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- Add support for EL10 and clones.
- Install audispd-plugins on EL8+ in auditd compatibility mode: since audit
  3.0 the af_unix plugin is a standalone program shipped in that package.
- Configure the af_unix plugin per audit version: use the standalone plugin
  path instead of the obsolete builtin_af_unix on EL8+.
- Send events to the socket in string format on EL8+, as recommended by
  Rapid7, who report that audit 3.1.1 and newer corrupt events in binary
  format. This requires Insight Agent newer than 4.0.8 in auditd
  compatibility mode. On EL9.6+ and EL10 the plugin expects binary input
  from auditd and takes the output format as an argument (RHEL-248251);
  on EL8 it passes events through unchanged.

## Release 2.0.0

- Add support for installing using package instead of .sh script. Defaults to
  package for EL8+ (breaking change if the package is not available).
- Add manage_audit_package parameter.
- Check for existing audit package resource before declaring audit package
  resource.
- Update to PDK 3.5.1.

## Release 1.1.0

- Add support for EL9 and clones.
- Add AlmaLinux and Rocky Linux as supported operating systems.
- Add manage_auditd attribute to disable managing auditd when auditd
  compatibility mode is enabled. By default, the module will manage auditd.
- Add checksum and checksum_type attributes to verify consistency of agent
  install script.
- Add semantic_version attribute for reinstalling the agent when the installed
  version is behind the target version.
- Add check for supported operating systems.
- Update to PDK 3.0.1.

## Release 1.0.0

Initial release
