# Changelog

All notable changes to this project will be documented in this file.

## Release 1.1.0

- Add support for EL9 and clones.
- Add AlmaLinux and Rocky Linux as supported operating systems.
- Add manage_auditd attribute to disable managing auditd when auditd
  compatibility mode is enabled. By default, the module will manage
  auditd.
- Add checksum and checksum_type attributes to verify consistency of
  agent install script.
- Add semantic_version attribute for reinstalling the agent when the
  installed version is behind the target version.
- Add check for supported operating systems.
- Update to PDK 3.0.1.

## Release 1.0.0

Initial release
