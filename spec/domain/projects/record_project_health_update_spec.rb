require 'spec_helper'
require 'domain/projects/record_project_health_update'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/persistence/fake_health_update_repository'
require_relative '../../support/project_builder'

RSpec.describe RecordProjectHealthUpdate do
  it 'fails when the project cannot be found' do
    project_repository = FakeProjectRepository.new
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: Date.today, health: :on_track)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'fails when the date is missing' do
    project = ProjectBuilder.build(name: 'Status')
    project_repository = FakeProjectRepository.new(projects: { '123' => project })
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: nil, health: :on_track)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['date is required'])
  end

  it 'fails when health is not allowed' do
    project = ProjectBuilder.build(name: 'Status')
    project_repository = FakeProjectRepository.new(projects: { '123' => project })
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: Date.today, health: :not_available)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid health'])
  end

  it 'fails when health is nil' do
    project = ProjectBuilder.build(name: 'Status')
    project_repository = FakeProjectRepository.new(projects: { '123' => project })
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: Date.today, health: nil)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid health'])
  end

  it 'fails when the date is in the future' do
    project = ProjectBuilder.build(name: 'Status')
    project_repository = FakeProjectRepository.new(projects: { '123' => project })
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    # Use the same date source as the action to avoid timezone issues
    current_date = Date.respond_to?(:current) ? Date.current : Date.today
    future_date = current_date + 1
    result = action.perform(project_id: '123', date: future_date, health: :on_track)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['date cannot be in the future'])
  end

  it 'treats non-date objects as not in the future' do
    project = ProjectBuilder.build(name: 'Status')
    project_repository = FakeProjectRepository.new(projects: { '123' => project })
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    non_date_object = Object.new
    result = action.perform(project_id: '123', date: non_date_object, health: :on_track)

    expect(result.success?).to be(true)
    stored_update = health_repository.all_for_project('123').first
    expect(stored_update.date).to eq(non_date_object)
  end

  it 'persists the health update when valid' do
    project = ProjectBuilder.build(name: 'Status')
    project_repository = FakeProjectRepository.new(projects: { '123' => project })
    health_repository = FakeHealthUpdateRepository.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    date = Date.new(2025, 1, 1)
    result = action.perform(project_id: '123', date: date, health: :on_track, description: 'Green')

    expect(result.success?).to be(true)
    stored_update = health_repository.all_for_project('123').first
    expect(stored_update.project_id).to eq('123')
    expect(stored_update.date).to eq(date)
    expect(stored_update.health).to eq(:on_track)
    expect(stored_update.description).to eq('Green')
  end
end
