require 'json'

Facter.add(:ir_agent) do
  confine kernel: 'Linux'
  confine do
    File.exist?('/opt/rapid7/ir_agent/ir_agent')
  end

  setcode do
    ir_agent = {}
    version = JSON.parse(`/opt/rapid7/ir_agent/ir_agent --version`)

    if version.key?('BuildVersion')
      ir_agent['build_version'] = version['BuildVersion']
    end

    if version.key?('SemanticVersion')
      ir_agent['semantic_version'] = version['SemanticVersion']
    end

    if File.exist?('/opt/rapid7/ir_agent/components/insight_agent/common/audit.conf')
      audit = JSON.parse(File.read('/opt/rapid7/ir_agent/components/insight_agent/common/audit.conf'))
      ir_agent['auditd_compatibility_mode'] = if audit.key?('auditd-compatibility-mode')
                                                audit['auditd-compatibility-mode']
                                              else
                                                false
                                              end
    else
      ir_agent['auditd_compatibility_mode'] = false
    end

    ir_agent
  end
end
