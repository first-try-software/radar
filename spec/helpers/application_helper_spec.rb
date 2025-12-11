require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#project_health_indicator' do
    it 'returns not available indicator for non-working states without loading the domain project' do
      record = instance_double('ProjectRecord', current_state: 'todo')
      actions = Rails.application.config.x.project_actions

      expect(actions.find_project).not_to receive(:perform)

      html = helper.project_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end

    it 'uses domain health for working states' do
      record = instance_double('ProjectRecord', id: '123', current_state: 'in_progress')
      domain_project = instance_double('Project', health: :off_track, current_state: :in_progress)
      result = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '123').and_return(result)

      html = helper.project_health_indicator(record)

      expect(html).to include('project-health--off_track')
    end

    it 'uses the domain project directly when it responds to health' do
      project = instance_double('Project', health: :on_track, current_state: :in_progress)

      html = helper.project_health_indicator(project)

      expect(html).to include('project-health--on_track')
      expect(html).to include('On Track')
    end

    it 'caches domain project lookups for working states' do
      record = instance_double('ProjectRecord', id: '123', current_state: 'in_progress')
      domain_project = instance_double('Project', health: :at_risk, current_state: :in_progress)
      result = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      expect(actions.find_project).to receive(:perform).once.with(id: '123').and_return(result)

      2.times { helper.project_health_indicator(record) }
    end
  end
end
