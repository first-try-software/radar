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

  it 'records whether it has been archived' do
    project = described_class.new(name: 'Status', archived: true)

    expect(project).to be_archived
  end

  it 'defaults archived to false when omitted' do
    project = described_class.new(name: 'Status')

    expect(project).not_to be_archived
  end

  it 'lazy loads subordinate projects via the loader' do
    loader = ->(_project) { [described_class.new(name: 'Child')] }
    project = described_class.new(name: 'Parent', subordinates_loader: loader)

    expect(project.subordinate_projects.map(&:name)).to eq(['Child'])
  end

  it 'defaults current_state to :new' do
    project = described_class.new(name: 'Status')

    expect(project.current_state).to eq(:new)
  end

  it 'raises when initialized with an invalid state' do
    expect do
      described_class.new(name: 'Status', current_state: :invalid)
    end.to raise_error(ArgumentError)
  end

  it 'returns a new project when updating state' do
    project = described_class.new(name: 'Status')

    updated = project.with_state(state: :todo)

    expect(updated.current_state).to eq(:todo)
    expect(updated).not_to equal(project)
  end
end
