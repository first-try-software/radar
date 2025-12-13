require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#project_health_indicator' do
    it 'loads domain project health for any state' do
      record = instance_double('ProjectRecord', id: '123')
      domain_project = instance_double('Project', health: :off_track)
      result = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '123').and_return(result)

      html = helper.project_health_indicator(record)

      expect(html).to include('project-health--off_track')
    end

    it 'uses the domain project directly when it responds to health' do
      project = instance_double('Project', health: :on_track)

      html = helper.project_health_indicator(project)

      expect(html).to include('project-health--on_track')
      expect(html).to include('On Track')
    end

    it 'caches domain project lookups' do
      record = instance_double('ProjectRecord', id: '123')
      domain_project = instance_double('Project', health: :at_risk)
      result = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      expect(actions.find_project).to receive(:perform).once.with(id: '123').and_return(result)

      2.times { helper.project_health_indicator(record) }
    end
  end

  describe '#project_health_trend' do
    it 'returns nil when project does not respond to health_trend' do
      project = instance_double('Object')

      result = helper.project_health_trend(project)

      expect(result).to be_nil
    end

    it 'returns nil when health_trend is empty' do
      project = instance_double('Project', health_trend: [])

      result = helper.project_health_trend(project)

      expect(result).to be_nil
    end

    it 'renders a dot for each week in the trend' do
      updates = [
        instance_double('HealthUpdate', date: Date.new(2025, 1, 6), health: :on_track, description: nil),
        instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :at_risk, description: nil),
        instance_double('HealthUpdate', date: Date.new(2025, 1, 20), health: :off_track, description: nil)
      ]
      project = instance_double('Project', health_trend: updates)

      html = helper.project_health_trend(project)

      expect(html).to include('health-trend-list')
      expect(html).to include('health-trend-list__dot--on_track')
      expect(html).to include('health-trend-list__dot--at_risk')
      expect(html).to include('health-trend-list__dot--off_track')
    end

    it 'includes tooltip with date and health' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :on_track, description: nil)
      project = instance_double('Project', health_trend: [update])

      html = helper.project_health_trend(project)

      expect(html).to include('health-trend-tooltip')
      expect(html).to include('1/13')
      expect(html).to include('On Track')
    end

    it 'includes description in tooltip when present' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :at_risk, description: 'Blocked on API')
      project = instance_double('Project', health_trend: [update])

      html = helper.project_health_trend(project)

      expect(html).to include('Blocked on API')
    end
  end

  describe '#project_health_indicator with tooltip' do
    it 'wraps indicator with tooltip when with_tooltip is true and updates exist' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :on_track, description: 'All good')
      project = instance_double(
        'Project',
        health: :on_track,
        children_health_for_tooltip: nil,
        health_updates_for_tooltip: [update]
      )

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).to include('health-indicator-wrapper')
      expect(html).to include('health-trend-tooltip')
      expect(html).to include('1/13')
      expect(html).to include('On Track')
      expect(html).to include('All good')
    end

    it 'returns plain indicator when with_tooltip is false' do
      project = instance_double('Project', health: :on_track)

      html = helper.project_health_indicator(project, with_tooltip: false)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'returns plain indicator when updates are empty and no children' do
      project = instance_double(
        'Project',
        health: :on_track,
        children_health_for_tooltip: nil,
        health_updates_for_tooltip: []
      )

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
    end

    it 'shows children health tooltip when project has children' do
      children_health = [
        OpenStruct.new(name: 'Child 1', health: :on_track),
        OpenStruct.new(name: 'Child 2', health: :off_track)
      ]
      project = instance_double(
        'Project',
        health: :at_risk,
        children_health_for_tooltip: children_health,
        health_updates_for_tooltip: nil
      )

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).to include('health-indicator-wrapper')
      expect(html).to include('health-rollup-tooltip')
      expect(html).to include('At Risk')
      expect(html).to include('Child 1')
      expect(html).to include('Child 2')
      expect(html).to include('project-health--on_track')
      expect(html).to include('project-health--off_track')
    end

    it 'returns plain indicator when project has no children and no health updates' do
      project = instance_double(
        'Project',
        health: :on_track,
        children_health_for_tooltip: nil,
        health_updates_for_tooltip: nil
      )

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
    end
  end
end
