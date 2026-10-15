# frozen_string_literal: true

require 'spec_helper'

describe 'ir_agent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:module_name) { 'ir_agent' }
      let(:package) { 'rapid7-insight-agent' }
      let(:home) { '/opt/rapid7' }
      let(:agent_installer) { "#{home}/agent_installer_x64.sh" }

      case os_facts[:os]['release']['major']
      when '6'
        let(:audit_rules) { '/etc/audit/audit.rules' }
        let(:audispd_conf) { '/etc/audisp/audispd.conf' }
        let(:audisp_plugins_dir) { '/etc/audisp/plugins.d' }
        let(:audisp_plugins_package) { nil }
        let(:af_unix_source) { "puppet:///modules/#{module_name}/af_unix.conf" }
        let(:af_unix_conf) { nil }
      when '7'
        let(:audit_rules) { '/etc/audit/rules.d/audit.rules' }
        let(:audispd_conf) { '/etc/audisp/audispd.conf' }
        let(:audisp_plugins_dir) { '/etc/audisp/plugins.d' }
        let(:audisp_plugins_package) { nil }
        let(:af_unix_source) { "puppet:///modules/#{module_name}/af_unix.conf" }
        let(:af_unix_conf) { nil }
      when '8'
        let(:audit_rules) { '/etc/audit/rules.d/audit.rules' }
        let(:audispd_conf) { '/etc/audit/auditd.conf' }
        let(:audisp_plugins_dir) { '/etc/audit/plugins.d' }
        let(:audisp_plugins_package) { 'audispd-plugins' }
        let(:af_unix_conf) do
          ['path = /sbin/audisp-af_unix', 'type = always', 'args = 0600 /var/run/audispd_events', 'format = string']
        end
      when '9', '10'
        let(:audit_rules) { '/etc/audit/rules.d/audit.rules' }
        let(:audispd_conf) { '/etc/audit/auditd.conf' }
        let(:audisp_plugins_dir) { '/etc/audit/plugins.d' }
        let(:audisp_plugins_package) { 'audispd-plugins' }
        let(:af_unix_conf) do
          ['path = /sbin/audisp-af_unix', 'type = always', 'args = 0600 /var/run/audispd_events string', 'format = binary']
        end
      end

      context 'with ensure => present' do
        let(:params) do
          {
            'ensure' => 'present',
            'source' => 'puppet:///modules/example/agent_installer.sh',
            'token' => 'us:01234567-89ab-cdef-0123-4567890abcde',
            'semantic_version' => '2.7.0.0',
          }
        end

        it do
          is_expected.to contain_class('ir_agent::audit')
          is_expected.to contain_class('ir_agent::install')
        end

        describe 'ir_agent::audit' do
          context 'with manage_audit_package => true' do
            let(:params) do
              super().merge({
                              'manage_audit_package' => true
                            })
            end

            it { is_expected.to contain_package('audit').with('ensure' => 'installed') }
          end

          context 'with manage_audit_package => false' do
            let(:params) do
              super().merge({
                              'manage_audit_package' => false
                            })
            end

            it { is_expected.not_to contain_package('audit') }
          end

          context 'with auditd_compatibility_mode => true' do
            let(:params) do
              super().merge({
                              'auditd_compatibility_mode' => true
                            })
            end

            it do
              is_expected.to contain_exec('stop_insight_agent')
                .with(
                  'command' => '/sbin/service ir_agent  stop',
                  'unless' => "/usr/bin/test -f #{home}/ir_agent/components/insight_agent/common/audit.conf",
                )
            end

            context 'with manage_auditd => true' do
              let(:params) do
                super().merge({
                                'manage_auditd' => true
                              })
              end

              it do
                is_expected.to contain_file(audit_rules)
                  .with(
                    'ensure' => 'file',
                    'source' => "puppet:///modules/#{module_name}/audit.rules",
                  )
                  .that_notifies('Service[auditd]')
                is_expected.to contain_exec('backup_af_unix_conf')
                  .with_creates("#{audisp_plugins_dir}/af_unix.conf.puppet-bak")
                  .that_requires('Package[audit]')
                  .that_comes_before("File[#{audisp_plugins_dir}/af_unix.conf]")
                is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                  .with_ensure('file')
                  .with_backup(false)
                  .that_requires('Package[audit]')
                  .that_notifies('Service[auditd]')
                if af_unix_conf
                  is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                    .with_content(%r{^active = yes$})
                  af_unix_conf.each do |line|
                    is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                      .with_content(%r{^#{Regexp.escape(line)}$})
                  end
                else
                  is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                    .with_source(af_unix_source)
                end
                is_expected.to contain_file_line('audispd.conf')
                  .with(
                    'ensure' => 'present',
                    'path' => audispd_conf,
                    'line' => 'q_depth = 8192',
                    'match' => '^q_depth =',
                  )
                  .that_requires('Package[audit]')
                  .that_notifies('Service[auditd]')
                is_expected.to contain_service('auditd')
                  .with(
                    'ensure' => 'running',
                    'enable' => true,
                    'restart' => '/sbin/service auditd restart',
                  )
                  .that_requires(['Package[audit]', 'Exec[stop_insight_agent]'])
                  .that_notifies('Service[ir_agent]')
              end

              it do
                if audisp_plugins_package
                  is_expected.to contain_package('audispd-plugins')
                    .with('ensure' => 'installed', 'name' => audisp_plugins_package)
                    .that_requires('Package[audit]')
                  is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                    .that_requires('Package[audispd-plugins]')
                else
                  is_expected.not_to contain_package('audispd-plugins')
                end
              end

              context 'with manage_audit_package => false' do
                let(:params) do
                  super().merge({
                                  'manage_audit_package' => false
                                })
                end

                it { is_expected.not_to contain_package('audispd-plugins') }
              end

              context 'with audispd-plugins declared elsewhere' do
                let(:pre_condition) { "package { 'audispd-plugins': ensure => installed }" }

                it do
                  if audisp_plugins_package
                    is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                      .that_requires('Package[audispd-plugins]')
                  end
                end
              end
            end

            context 'with manage_auditd => false' do
              let(:params) do
                super().merge({
                                'manage_auditd' => false
                              })
              end

              it do
                is_expected.not_to contain_file(audit_rules)
                is_expected.not_to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                is_expected.not_to contain_file_line('audispd.conf')
                is_expected.not_to contain_service('auditd')
              end
            end

            it do
              is_expected.to contain_file("#{home}/ir_agent/components/insight_agent/common/audit.conf")
                .with(
                  'ensure' => 'file',
                  'content' => '{"auditd-compatibility-mode":true}',
                )
                .that_notifies('Service[ir_agent]')
            end
          end

          context 'with auditd_compatibility_mode => false' do
            let(:params) do
              super().merge({
                              'auditd_compatibility_mode' => false
                            })
            end

            it do
              is_expected.to contain_service('auditd')
                .with(
                  'ensure' => 'stopped',
                  'stop' => '/sbin/service auditd stop',
                )
                .that_requires('Package[audit]')
                .that_notifies('Service[ir_agent]')
              is_expected.to contain_file("#{home}/ir_agent/components/insight_agent/common/audit.conf")
                .with(
                  'ensure' => 'absent',
                )
                .that_notifies('Service[ir_agent]')
            end
          end
        end

        describe 'ir_agent::install' do
          let(:proxy_config) { "#{home}/ir_agent/components/bootstrap/common/proxy.config" }

          [:undef, 'proxy.example.org:3128'].each do |https_proxy|
            context "with https_proxy => #{https_proxy}" do
              let(:params) do
                super().merge({
                                'https_proxy' => https_proxy,
                              })
              end

              if https_proxy == :undef
                let(:install_args) { "--token #{params['token']}" }
              else
                let(:install_args) { "--token #{params['token']} --https-proxy #{https_proxy}" }
              end

              context 'with installer => package' do
                let(:params) do
                  super().merge({
                                  'installer' => 'package',
                                })
                end

                it do
                  is_expected.to contain_package(package)
                  is_expected.to contain_exec('configure_insight_agent')
                    .that_requires("Package[#{package}]")
                end
              end

              context 'with installer => .sh' do
                let(:params) do
                  super().merge({
                                  'installer' => '.sh',
                                })
                end

                it do
                  is_expected.to contain_file(home).with('ensure' => 'directory')
                  is_expected.to contain_file('insight_agent_installer')
                    .with(
                      'ensure' => 'file',
                      'path'   => agent_installer,
                    )
                end

                context 'install' do
                  it do
                    is_expected.to contain_exec('install_insight_agent')
                      .with(
                        'command' => "#{agent_installer} install_start #{install_args}",
                        'creates' => "#{home}/ir_agent/ir_agent",
                      )
                      .that_requires('File[insight_agent_installer]')
                  end
                end

                context 'reininstall' do
                  let(:facts) do
                    super().merge({
                                    'ir_agent' => { 'semantic_version' => '1.1.2.6' },
                                  })
                  end

                  it do
                    is_expected.to contain_exec('install_insight_agent')
                      .with(
                        'command' => "#{agent_installer} reinstall_start #{install_args}",
                      )
                      .that_requires('File[insight_agent_installer]')
                  end
                end
              end

              if https_proxy == :undef
                it do
                  is_expected.to contain_file('insight_agent_proxy_config')
                    .with(
                      'ensure' => 'absent',
                      'path' => proxy_config,
                    )
                    .that_notifies('Service[ir_agent]')
                end
              else
                it do
                  is_expected.to contain_file('insight_agent_proxy_config')
                    .with(
                      'ensure' => 'file',
                      'path' => proxy_config,
                      'content' => "{\"https\": \"#{params['https_proxy']}\"}\n",
                      'mode' => '0700',
                    )
                    .that_notifies('Service[ir_agent]')
                end
              end
            end
          end

          it do
            is_expected.to contain_service('ir_agent')
              .with(
                'ensure' => 'running',
                'enable' => true,
              )
          end
        end
      end

      context 'with ensure => absent' do
        let(:params) do
          {
            'ensure' => 'absent'
          }
        end

        it { is_expected.to contain_class('ir_agent::uninstall') }

        describe 'ir_agent::uninstall' do
          context 'with installer => package' do
            let(:params) do
              super().merge({
                              'installer' => 'package'
                            })
            end

            it do
              is_expected.to contain_package(package)
                .with('ensure' => 'absent')
            end
          end

          context 'with installer => .sh' do
            let(:params) do
              super().merge({
                              'installer' => '.sh'
                            })
            end

            it do
              is_expected.to contain_exec('uninstall_insight_agent')
                .with(
                  'command' => "#{agent_installer} uninstall",
                  'onlyif' => "/usr/bin/test -x #{agent_installer}",
                )
            end
          end

          context 'with manage_auditd => true' do
            let(:params) do
              super().merge({
                              'manage_auditd' => true
                            })
            end

            it do
              is_expected.to contain_exec('restore_audit_rules')
                .with('refreshonly' => true)
              is_expected.to contain_exec('restore_af_unix_conf')
                .with('refreshonly' => true)
              is_expected.to contain_exec('start_auditd')
                .with('refreshonly' => true)
            end
          end
        end
      end
    end
  end
end
