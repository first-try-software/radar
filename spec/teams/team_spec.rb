require 'spec_helper'
require_relative '../../domain/teams/team'

RSpec.describe Team do
  it 'returns its name' do
    team = described_class.new(name: 'Platform')

    expect(team.name).to eq('Platform')
  end

  it 'returns its mission' do
    team = described_class.new(name: 'Platform', mission: 'Enable delivery velocity')

    expect(team.mission).to eq('Enable delivery velocity')
  end

  it 'returns its vision' do
    team = described_class.new(name: 'Platform', vision: 'Create clarity')

    expect(team.vision).to eq('Create clarity')
  end

  it 'defaults vision to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.vision).to eq('')
  end

  it 'defaults mission to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.mission).to eq('')
  end

  it 'returns its point of contact' do
    team = described_class.new(name: 'Platform', point_of_contact: 'Jordan')

    expect(team.point_of_contact).to eq('Jordan')
  end

  it 'defaults point_of_contact to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.point_of_contact).to eq('')
  end

  it 'records whether it has been archived' do
    team = described_class.new(name: 'Platform', archived: true)

    expect(team).to be_archived
  end

  it 'defaults archived to false' do
    team = described_class.new(name: 'Platform')

    expect(team).not_to be_archived
  end

  it 'is valid when it has a name' do
    team = described_class.new(name: 'Platform')

    expect(team.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    team = described_class.new(name: '')

    expect(team.valid?).to be(false)
  end

  it 'returns validation errors when invalid' do
    team = described_class.new(name: '')

    expect(team.errors).to eq(['name must be present'])
  end

  it 'returns no validation errors when valid' do
    team = described_class.new(name: 'Platform')

    expect(team.errors).to eq([])
  end

  it 'lazy loads owned projects via the loader' do
    loader = ->(_team) { [double('Project')] }
    team = described_class.new(name: 'Platform', owned_projects_loader: loader)

    expect(team.owned_projects.length).to eq(1)
  end

  it 'lazy loads subordinate teams via the loader' do
    loader = ->(_team) { [double('Team')] }
    team = described_class.new(name: 'Platform', subordinate_teams_loader: loader)

    expect(team.subordinate_teams.length).to eq(1)
  end
end
