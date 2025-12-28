# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectListItemPresenter, type: :helper do
  let(:view_context) { helper }

  describe '#health' do
    it 'returns health_override when provided' do
      project = double('Project', name: 'Test', health: :on_track)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(
        project: project,
        view_context: view_context,
        health_override: :off_track
      )

      expect(presenter.health).to eq(:off_track)
    end

    it 'returns not_available when project does not respond to health' do
      project = double('Project', name: 'Test')
      allow(project).to receive(:respond_to?).with(:health).and_return(false)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.health).to eq(:not_available)
    end

    it 'returns project health when available' do
      project = double('Project', name: 'Test', health: :at_risk)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.health).to eq(:at_risk)
    end

    it 'returns not_available when project health is nil' do
      project = double('Project', name: 'Test', health: nil)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.health).to eq(:not_available)
    end
  end

  describe '#health_css_class' do
    it 'converts underscores to hyphens' do
      project = double('Project', name: 'Test', health: :at_risk)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.health_css_class).to eq('at-risk')
    end
  end

  describe '#name' do
    it 'returns the project name' do
      project = double('Project', name: 'My Project', health: :on_track)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'My Project')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.name).to eq('My Project')
    end
  end

  describe '#state_label' do
    it 'formats the state nicely' do
      project = double('Project', name: 'Test', current_state: :in_progress, health: :on_track)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.state_label).to eq('In Progress')
    end
  end

  describe '#state_css_class' do
    it 'includes the state in the class' do
      project = double('Project', name: 'Test', current_state: :blocked, health: :on_track)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.state_css_class).to eq('project-item-v2__state project-item-v2__state--blocked')
    end
  end

  describe '#contact' do
    it 'returns point of contact when present' do
      project = double('Project', name: 'Test', point_of_contact: 'John Doe', health: :on_track)
      allow(project).to receive(:respond_to?).with(:point_of_contact).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.contact).to eq('John Doe')
    end

    it 'returns em dash when point of contact is blank' do
      project = double('Project', name: 'Test', point_of_contact: '', health: :on_track)
      allow(project).to receive(:respond_to?).with(:point_of_contact).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.contact).to eq('—')
    end

    it 'returns em dash when project does not respond to point_of_contact' do
      project = double('Project', name: 'Test', health: :on_track)
      allow(project).to receive(:respond_to?).with(:point_of_contact).and_return(false)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.contact).to eq('—')
    end
  end

  describe '#path' do
    it 'returns the project path' do
      project = double('Project', name: 'Test', health: :on_track)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      record = ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.path).to eq("/projects/#{record.id}")
    end
  end

  describe '#trend_direction' do
    it 'returns the project trend when available' do
      project = double('Project', name: 'Test', health: :on_track, trend: :up)
      allow(project).to receive(:respond_to?).with(:trend).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.trend_direction).to eq(:up)
    end

    it 'returns stable when project does not respond to trend' do
      project = double('Project', name: 'Test', health: :on_track)
      allow(project).to receive(:respond_to?).with(:trend).and_return(false)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.trend_direction).to eq(:stable)
    end
  end

  describe '#trend_arrow' do
    it 'returns an SVG for the trend direction' do
      project = double('Project', name: 'Test', health: :on_track, trend: :up)
      allow(project).to receive(:respond_to?).with(:trend).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.trend_arrow).to include('trend-arrow--up')
    end
  end

  describe '#projects_count' do
    it 'returns zero when project has no children' do
      project = double('Project', name: 'Test', health: :on_track, children: [])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.projects_count).to eq(0)
    end

    it 'returns the count of active children' do
      child1 = double('Child1')
      allow(child1).to receive(:respond_to?).with(:archived?).and_return(false)
      child2 = double('Child2')
      allow(child2).to receive(:respond_to?).with(:archived?).and_return(true)
      allow(child2).to receive(:archived?).and_return(true)
      child3 = double('Child3')
      allow(child3).to receive(:respond_to?).with(:archived?).and_return(true)
      allow(child3).to receive(:archived?).and_return(false)

      project = double('Project', name: 'Test', health: :on_track, children: [child1, child2, child3])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.projects_count).to eq(2)
    end

    it 'returns zero when project does not respond to children' do
      project = double('Project', name: 'Test', health: :on_track)
      allow(project).to receive(:respond_to?).with(:children).and_return(false)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.projects_count).to eq(0)
    end
  end

  describe '#stale_count' do
    it 'returns zero when no children' do
      project = double('Project', name: 'Test', health: :on_track, children: [])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.stale_count).to eq(0)
    end

    it 'counts stale leaf children' do
      old_update = double('HealthUpdate', date: Date.current - 10)
      child = double('Child', current_state: :in_progress, latest_health_update: old_update)
      allow(child).to receive(:respond_to?).with(:archived?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf?).and_return(true)
      allow(child).to receive(:leaf?).and_return(true)

      project = double('Project', name: 'Test', health: :on_track, children: [child])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.stale_count).to eq(1)
    end

    it 'does not count children with done state' do
      old_update = double('HealthUpdate', date: Date.current - 10)
      child = double('Child', current_state: :done, latest_health_update: old_update)
      allow(child).to receive(:respond_to?).with(:archived?).and_return(false)

      project = double('Project', name: 'Test', health: :on_track, children: [child])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.stale_count).to eq(0)
    end

    it 'counts children with nil health update' do
      child = double('Child', current_state: :in_progress, latest_health_update: nil)
      allow(child).to receive(:respond_to?).with(:archived?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf?).and_return(true)
      allow(child).to receive(:leaf?).and_return(true)

      project = double('Project', name: 'Test', health: :on_track, children: [child])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.stale_count).to eq(1)
    end

    it 'counts parent children based on their leaf descendants' do
      old_update = double('HealthUpdate', date: Date.current - 10)
      leaf = double('Leaf', latest_health_update: old_update)

      child = double('Child', current_state: :in_progress, leaf_descendants: [leaf])
      allow(child).to receive(:respond_to?).with(:archived?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf?).and_return(true)
      allow(child).to receive(:leaf?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf_descendants).and_return(true)

      project = double('Project', name: 'Test', health: :on_track, children: [child])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.stale_count).to eq(1)
    end

    it 'does not count fresh parent children' do
      recent_update = double('HealthUpdate', date: Date.current - 3)
      leaf = double('Leaf', latest_health_update: recent_update)

      child = double('Child', current_state: :in_progress, leaf_descendants: [leaf])
      allow(child).to receive(:respond_to?).with(:archived?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf?).and_return(true)
      allow(child).to receive(:leaf?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf_descendants).and_return(true)

      project = double('Project', name: 'Test', health: :on_track, children: [child])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      expect(presenter.stale_count).to eq(0)
    end

    it 'handles parent child without leaf_descendants method' do
      child = double('Child', current_state: :in_progress)
      allow(child).to receive(:respond_to?).with(:archived?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf?).and_return(true)
      allow(child).to receive(:leaf?).and_return(false)
      allow(child).to receive(:respond_to?).with(:leaf_descendants).and_return(false)

      project = double('Project', name: 'Test', health: :on_track, children: [child])
      allow(project).to receive(:respond_to?).with(:children).and_return(true)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)
      ProjectRecord.create!(name: 'Test')

      presenter = ProjectListItemPresenter.new(project: project, view_context: view_context)

      # No leaf_descendants means nil latest, which counts as stale
      expect(presenter.stale_count).to eq(1)
    end
  end
end
