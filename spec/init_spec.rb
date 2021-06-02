require 'spec_helper.rb'

describe 'ir_agent' do
  let(:title) { 'ir_agent' }
  let(:node) { 'text.example.org' }

  it { is_expected.to compile }
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('nginx').with(ensure: `installed`) }
end
