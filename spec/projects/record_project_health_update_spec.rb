require 'spec_helper'
require_relative '../../domain/projects/record_project_health_update'
require_relative '../../domain/projects/project'

RSpec.describe RecordProjectHealthUpdate do
  class ProjectRepoDouble
    def initialize(projects: {})
      @projects = projects
    end

    def find(id)
      @projects[id]
    end
  end

  class HealthUpdateRepoDouble
    attr_reader :records

    def initialize
      @records = []
    end

    def save(health_update)
      records << health_update
    end
  end

  it 'fails when the project cannot be found' do
    project_repository = ProjectRepoDouble.new
    health_repository = HealthUpdateRepoDouble.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: Date.today, health: :on_track)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'fails when the project state does not allow updates' do
    project = Project.new(name: 'Status', current_state: :todo)
    project_repository = ProjectRepoDouble.new(projects: { '123' => project })
    health_repository = HealthUpdateRepoDouble.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: Date.today, health: :on_track)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid project state'])
  end

  it 'fails when the date is missing' do
    project = Project.new(name: 'Status', current_state: :in_progress)
    project_repository = ProjectRepoDouble.new(projects: { '123' => project })
    health_repository = HealthUpdateRepoDouble.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: nil, health: :on_track)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['date is required'])
  end

  it 'fails when health is not allowed' do
    project = Project.new(name: 'Status', current_state: :in_progress)
    project_repository = ProjectRepoDouble.new(projects: { '123' => project })
    health_repository = HealthUpdateRepoDouble.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    result = action.perform(project_id: '123', date: Date.today, health: :not_available)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid health'])
  end

  it 'persists the health update when valid' do
    project = Project.new(name: 'Status', current_state: :in_progress)
    project_repository = ProjectRepoDouble.new(projects: { '123' => project })
    health_repository = HealthUpdateRepoDouble.new
    action = described_class.new(
      project_repository: project_repository,
      health_update_repository: health_repository
    )

    date = Date.new(2025, 1, 1)
    result = action.perform(project_id: '123', date: date, health: :on_track, description: 'Green')

    expect(result.success?).to be(true)
    stored_update = health_repository.records.first
    expect(stored_update.project_id).to eq('123')
    expect(stored_update.date).to eq(date)
    expect(stored_update.health).to eq(:on_track)
    expect(stored_update.description).to eq('Green')
  end
end
