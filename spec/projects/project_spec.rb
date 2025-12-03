require 'spec_helper'
require_relative '../../domain/projects/project'

RSpec.describe Project do
  it 'returns its name' do
    project = described_class.new(name: 'Status')

    expect(project.name).to eq('Status')
  end

  it 'returns its description' do
    project = described_class.new(name: 'Status', description: 'Internal status dashboard')

    expect(project.description).to eq('Internal status dashboard')
  end

  it 'defaults description to an empty string when omitted' do
    project = described_class.new(name: 'Status')

    expect(project.description).to eq('')
  end

  it 'returns its point of contact' do
    project = described_class.new(name: 'Status', point_of_contact: 'Alex')

    expect(project.point_of_contact).to eq('Alex')
  end

  it 'defaults point_of_contact to an empty string when omitted' do
    project = described_class.new(name: 'Status')

    expect(project.point_of_contact).to eq('')
  end

  it 'is valid when it has a name' do
    project = described_class.new(name: 'Status')

    expect(project.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    project = described_class.new(name: '')

    expect(project.valid?).to be(false)
  end
end
