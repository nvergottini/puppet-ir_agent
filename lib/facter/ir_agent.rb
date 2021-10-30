require 'json'

Facter.add(:ir_agent) do
  confine :kernel => 'Linux'
  confine do
    File.exist?('/opt/rapid7/ir_agent/ir_agent')
  end

  setcode do
    ir_agent = JSON.parse(`/opt/rapid7/ir_agent/ir_agent --version`)

    if File.exist?('/opt/rapid7/ir_agent/components/insight_agent/common/audit.conf')
      audit = JSON.parse(File.read('/opt/rapid7/ir_agent/components/insight_agent/common/audit.conf'))
      ir_agent.merge!(audit)
    else
      ir_agent['auditd-compatibility-mode'] = false
    end
    
    ir_agent
  end
end
