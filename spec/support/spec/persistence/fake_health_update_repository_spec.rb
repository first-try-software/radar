require 'spec_helper'
require 'date'

require_relative '../../persistence/fake_health_update_repository'
require 'domain/projects/health_update'

RSpec.describe FakeHealthUpdateRepository do
  it 'stores health updates when saved' do
    repository = FakeHealthUpdateRepository.new
    health_update = HealthUpdate.new(project_id: '123', date: Date.today, health: :on_track)

    repository.save(health_update)

    expect(repository.all_for_project('123')).to eq([health_update])
  end

  it 'retains previously saved updates' do
    existing = [HealthUpdate.new(project_id: 'existing', date: Date.today, health: :on_track)]
    repository = FakeHealthUpdateRepository.new(records: existing)
    health_update = HealthUpdate.new(project_id: 'new', date: Date.today, health: :at_risk)

    repository.save(health_update)

    expect(repository.all_for_project('existing')).to eq(existing)
    expect(repository.all_for_project('new')).to eq([health_update])
  end
end
