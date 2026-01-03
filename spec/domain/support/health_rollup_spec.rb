require 'spec_helper'
require 'domain/support/health_rollup'

RSpec.describe HealthRollup do
  it 'returns :not_available when no projects are provided' do
    expect(described_class.health_from_projects([])).to eq(:not_available)
  end

  it 'ignores projects not in working states' do
    projects = [
      double('Project', current_state: :todo, health: :on_track),
      double('Project', current_state: :done, health: :off_track)
    ]

    expect(described_class.health_from_projects(projects)).to eq(:not_available)
  end

  it 'returns :on_track when average score is >= 0.51' do
    projects = [
      double('Project', current_state: :in_progress, health: :on_track),
      double('Project', current_state: :in_progress, health: :on_track),
      double('Project', current_state: :blocked, health: :at_risk)
    ]
    # Average = (1 + 1 + 0) / 3 = 0.67

    expect(described_class.health_from_projects(projects)).to eq(:on_track)
  end

  it 'returns :at_risk when average score is zero' do
    projects = [
      double('Project', current_state: :in_progress, health: :on_track),
      double('Project', current_state: :blocked, health: :off_track)
    ]

    expect(described_class.health_from_projects(projects)).to eq(:at_risk)
  end

  it 'returns :off_track when average score is negative' do
    projects = [
      double('Project', current_state: :in_progress, health: :off_track),
      double('Project', current_state: :blocked, health: :off_track)
    ]

    expect(described_class.health_from_projects(projects)).to eq(:off_track)
  end

  it 'ignores projects whose health is :not_available' do
    projects = [
      double('Project', current_state: :in_progress, health: :not_available),
      double('Project', current_state: :blocked, health: :on_track)
    ]

    expect(described_class.health_from_projects(projects)).to eq(:on_track)
  end

  it 'rounds slightly positive averages down to :at_risk' do
    projects = [
      double('Project', current_state: :in_progress, health: :on_track),
      double('Project', current_state: :blocked, health: :at_risk),
      double('Project', current_state: :blocked, health: :at_risk),
      double('Project', current_state: :blocked, health: :at_risk)
    ]

    expect(described_class.health_from_projects(projects)).to eq(:at_risk)
  end

  it 'rounds slightly negative averages up to :at_risk' do
    projects = [
      double('Project', current_state: :in_progress, health: :off_track),
      double('Project', current_state: :blocked, health: :at_risk),
      double('Project', current_state: :blocked, health: :at_risk),
      double('Project', current_state: :blocked, health: :at_risk)
    ]

    expect(described_class.health_from_projects(projects)).to eq(:at_risk)
  end
end
