# frozen_string_literal: true

require "spec_helper"

describe "ir_agent" do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:module_name) { "ir_agent" }
      let(:home) { "/opt/rapid7" }
      let(:agent_installer) { "#{home}/agent_installer_x64.sh" }

      case os_facts[:os]["release"]["major"]
      when '6'
        let(:audit_rules) { "/etc/audit/audit.rules" }
        let(:audispd_conf) { "/etc/audisp/audispd.conf" }
        let(:audisp_plugins_dir) { "/etc/audisp/plugins.d" }
      when '7'
        let(:audit_rules) { "/etc/audit/rules.d/audit.rules" }
        let(:audispd_conf) { "/etc/audisp/audispd.conf" }
        let(:audisp_plugins_dir) { "/etc/audisp/plugins.d" }
      when '8'
        let(:audit_rules) { "/etc/audit/rules.d/audit.rules" }
        let(:audispd_conf) { "/etc/audit/auditd.conf" }
        let(:audisp_plugins_dir) { "/etc/audit/plugins.d" }
      end

      context "with ensure => present" do
        let(:params) do
          {
            "ensure" => "present",
            "source" => "puppet:///modules/example/agent_installer.sh",
            "token" => "us:01234567-89ab-cdef-0123-4567890abcde"
          }
        end

        it do
          is_expected.to contain_class("ir_agent::audit")
          is_expected.to contain_class("ir_agent::install")
        end

        describe "ir_agent::audit" do
          it { is_expected.to contain_package("audit").with("ensure" => "installed") }

          context "with auditd_compatibility_mode => true" do
            let(:params) do
              super().merge({
                "auditd_compatibility_mode" => true
              })
            end

            it do
              is_expected.to contain_exec("stop_insight_agent")
                .with(
                  "command" => "/sbin/service ir_agent  stop",
                  "unless" => "/usr/bin/test -f #{home}/ir_agent/components/insight_agent/common/audit.conf"
                )
                .that_requires("Exec[install_insight_agent]")
            end

            it do
              is_expected.to contain_file(audit_rules)
                .with(
                  "ensure" => "file",
                  "source" => "puppet:///modules/#{module_name}/audit.rules"
                )
                .that_notifies("Service[auditd]")
            end

            it do
              is_expected.to contain_file("#{audisp_plugins_dir}/af_unix.conf")
                .with(
                  "ensure" => "file",
                  "source" => "puppet:///modules/#{module_name}/af_unix.conf"
                )
                .that_requires("Package[audit]")
                .that_notifies("Service[auditd]")
            end

            it do
              is_expected.to contain_file_line("audispd.conf")
                .with(
                  "ensure" => "present",
                  "path" => audispd_conf,
                  "line" => "q_depth = 8192",
                  "match" => "^q_depth ="
                )
                .that_requires("Package[audit]")
                .that_notifies("Service[auditd]")
            end

            it do
              is_expected.to contain_file("#{home}/ir_agent/components/insight_agent/common/audit.conf")
                .with(
                  "ensure" => "file",
                  "content" => '{"auditd-compatibility-mode":true}'
                )
                .that_requires("Exec[install_insight_agent]")
                .that_notifies("Service[ir_agent]")
            end

            it do
              is_expected.to contain_service("auditd")
                .with(
                  "ensure" => "running",
                  "enable" => true,
                  "restart" => "/sbin/service auditd restart"
                )
                .that_requires(["Package[audit]", "Exec[stop_insight_agent]"])
                .that_notifies("Service[ir_agent]")
            end
          end

          context "with auditd_compatibility_mode => false" do
            let(:params) do
              super().merge({
                "auditd_compatibility_mode" => false
              })
            end

            it do
              is_expected.to contain_service("auditd")
                .with(
                  "ensure" => "stopped",
                  "stop" => "/sbin/service auditd stop"
                )
                .that_requires("Package[audit]")
                .that_notifies("Service[ir_agent]")
            end

            it do
              is_expected.to contain_file("#{home}/ir_agent/components/insight_agent/common/audit.conf")
                .with(
                  "ensure" => "absent"
                )
                .that_requires("Exec[install_insight_agent]")
                .that_notifies("Service[ir_agent]")
            end
          end
        end

        describe "ir_agent::install" do
          let(:proxy_config) { "#{home}/ir_agent/components/bootstrap/common/proxy.config" }

          it do
            is_expected.to contain_file(home).with("ensure" => "directory")
            is_expected.to contain_file(agent_installer).with("ensure" => "file")
          end

          context "with proxy" do
            let(:params) do
              super().merge({
                "https_proxy" => "proxy.example.org:3128"
              })
            end

            let(:agent_install_cmd) do
              <<~CMD.tr("\n", " ").strip
                #{agent_installer} install_start
                --token #{params["token"]}
                --https-proxy #{params["https_proxy"]}
              CMD
            end

            it do
              is_expected.to contain_exec("install_insight_agent")
                .with(
                  "command" => agent_install_cmd,
                  "creates" => "#{home}/ir_agent/ir_agent"
                )
                .that_requires("File[#{agent_installer}]")
            end

            it do
              is_expected.to contain_file(proxy_config)
                .with(
                  "ensure" => "file",
                  "content" => "{\"https\": \"#{params["https_proxy"]}\"}\n",
                  "mode" => "0700"
                )
                .that_notifies("Service[ir_agent]")
            end
          end

          context "without proxy" do
            let(:params) do
              super().merge({
                "https_proxy" => :undef
              })
            end

            let(:agent_install_cmd) { "#{agent_installer} install_start --token #{params["token"]}" }

            it do
              is_expected.to contain_exec("install_insight_agent")
                .with(
                  "command" => agent_install_cmd,
                  "creates" => "#{home}/ir_agent/ir_agent"
                )
                .that_requires("File[#{agent_installer}]")
            end

            it do
              is_expected.to contain_file(proxy_config)
                .with("ensure" => "absent")
                .that_notifies("Service[ir_agent]")
            end
          end

          it do
            is_expected.to contain_service("ir_agent")
              .with(
                "ensure" => "running",
                "enable" => true
              )
              .that_requires("Exec[install_insight_agent]")
          end
        end
      end

      context "with ensure => absent" do
        let(:params) do
          {
            "ensure" => "absent"
          }
        end

        it { is_expected.to contain_class("ir_agent::uninstall") }

        describe "ir_agent::uninstall" do
          it do
            is_expected.to contain_exec("uninstall_insight_agent")
              .with(
                "command" => "#{agent_installer} uninstall",
                "onlyif" => "/usr/bin/test -x #{agent_installer}"
              )
          end

          it do
            is_expected.to contain_exec("restore_audit_rules")
              .with("refreshonly" => true)
              .that_subscribes_to("Exec[uninstall_insight_agent]")
          end

          it do
            is_expected.to contain_exec("restore_af_unix_conf")
              .with("refreshonly" => true)
              .that_subscribes_to("Exec[uninstall_insight_agent]")
          end

          it do
            is_expected.to contain_exec("start_auditd")
              .with("refreshonly" => true)
              .that_subscribes_to("Exec[uninstall_insight_agent]")
          end
        end
      end
    end
  end
end
