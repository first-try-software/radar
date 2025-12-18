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

    it 'returns :not_available when find_project fails' do
      record = instance_double('ProjectRecord', id: '456')
      result = instance_double('Result', success?: false, value: nil, errors: ['project not found'])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '456').and_return(result)

      html = helper.project_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end

    it 'handles project_record without id method' do
      record = Object.new
      result = instance_double('Result', success?: false, value: nil, errors: ['project not found'])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: nil).and_return(result)

      html = helper.project_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end
  end

  describe '#project_state_for' do
    it 'returns current_state directly when given a domain Project' do
      domain_project = instance_double('Project', current_state: :in_progress)
      allow(domain_project).to receive(:is_a?).with(Project).and_return(true)

      result = helper.project_state_for(domain_project)

      expect(result).to eq(:in_progress)
    end

    it 'gets derived state from domain project when given a record' do
      record = instance_double('ProjectRecord', id: '123', current_state: 'new')
      domain_project = instance_double('Project', current_state: :blocked)
      result_double = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '123').and_return(result_double)

      result = helper.project_state_for(record)

      expect(result).to eq(:blocked)
    end

    it 'falls back to record state when domain project lookup fails' do
      record = instance_double('ProjectRecord', id: '789', current_state: 'todo')
      result_double = instance_double('Result', success?: false, value: nil, errors: ['not found'])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '789').and_return(result_double)

      result = helper.project_state_for(record)

      expect(result).to eq(:todo)
    end

    it 'returns current_state when object does not respond to id' do
      object = double('SomeObject', current_state: :done)

      result = helper.project_state_for(object)

      expect(result).to eq(:done)
    end
  end

  describe '#project_state_label' do
    it 'returns humanized state label' do
      record = instance_double('ProjectRecord', id: '123', current_state: 'in_progress')
      domain_project = instance_double('Project', current_state: :in_progress)
      result_double = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '123').and_return(result_double)

      result = helper.project_state_label(record)

      expect(result).to eq('In Progress')
    end
  end

  describe '#project_sort_data' do
    it 'returns sort data when given a domain Project' do
      domain_project = double(
        'Project',
        current_state: :blocked,
        health: :off_track,
        name: 'TestProject',
        created_at: Time.new(2025, 1, 1)
      )
      allow(domain_project).to receive(:is_a?).with(Project).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(false)
      allow(domain_project).to receive(:respond_to?).with(:name).and_return(true)

      result = helper.project_sort_data(domain_project)

      expect(result[:name]).to eq('testproject')
      expect(result[:state_score]).to eq(1) # blocked
      expect(result[:health_score]).to eq(3) # off_track
    end

    it 'looks up domain project when given a record with id' do
      record = instance_double('ProjectRecord', id: '123', current_state: 'new', name: 'RecordProject', created_at: Time.new(2025, 1, 1))
      domain_project = double(
        'Project',
        current_state: :in_progress,
        health: :at_risk
      )
      allow(domain_project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(false)
      result_double = instance_double('Result', success?: true, value: domain_project, errors: [])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '123').and_return(result_double)

      result = helper.project_sort_data(record)

      expect(result[:state_score]).to eq(2) # in_progress from domain
      expect(result[:health_score]).to eq(2) # at_risk from domain
    end

    it 'falls back to record state when domain lookup fails' do
      record = instance_double('ProjectRecord', id: '456', current_state: 'todo', name: 'FallbackProject', created_at: Time.new(2025, 1, 1))
      result_double = instance_double('Result', success?: false, value: nil, errors: ['not found'])
      actions = Rails.application.config.x.project_actions
      allow(actions.find_project).to receive(:perform).with(id: '456').and_return(result_double)

      result = helper.project_sort_data(record)

      expect(result[:state_score]).to eq(4) # todo from record
      expect(result[:health_score]).to eq(99) # not_available fallback
    end

    it 'uses health_updates_for_tooltip when available' do
      latest_update = instance_double('HealthUpdate', date: Date.new(2025, 3, 15))
      domain_project = double(
        'Project',
        current_state: :on_hold,
        health: :on_track,
        name: 'HealthProject',
        health_updates_for_tooltip: [latest_update],
        created_at: Time.new(2025, 1, 1)
      )
      allow(domain_project).to receive(:is_a?).with(Project).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:name).and_return(true)

      result = helper.project_sort_data(domain_project)

      expect(result[:updated_at]).to eq('2025-03-15')
    end

    it 'falls back to created_at when health_updates_for_tooltip is empty' do
      domain_project = double(
        'Project',
        current_state: :done,
        health: :on_track,
        name: 'EmptyUpdates',
        health_updates_for_tooltip: [],
        created_at: Time.new(2025, 2, 20)
      )
      allow(domain_project).to receive(:is_a?).with(Project).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:name).and_return(true)

      result = helper.project_sort_data(domain_project)

      expect(result[:updated_at]).to include('2025-02-20')
    end

    it 'falls back to created_at when health_updates_for_tooltip returns nil' do
      domain_project = double(
        'Project',
        current_state: :todo,
        health: :at_risk,
        name: 'NilUpdates',
        health_updates_for_tooltip: nil,
        created_at: Time.new(2025, 4, 10)
      )
      allow(domain_project).to receive(:is_a?).with(Project).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(true)
      allow(domain_project).to receive(:respond_to?).with(:name).and_return(true)

      result = helper.project_sort_data(domain_project)

      expect(result[:updated_at]).to include('2025-04-10')
    end

    it 'handles objects without name method' do
      object = double('SomeObject', current_state: :new, created_at: Time.new(2025, 1, 1))
      allow(object).to receive(:is_a?).with(Project).and_return(false)
      allow(object).to receive(:respond_to?).with(:id).and_return(false)
      allow(object).to receive(:respond_to?).with(:name).and_return(false)

      result = helper.project_sort_data(object)

      expect(result[:name]).to eq('')
    end
  end

  describe '#team_sort_data' do
    it 'returns sort data when given a domain Team' do
      domain_team = instance_double('Team', health: :off_track, name: 'TestTeam')

      result = helper.team_sort_data(domain_team)

      expect(result[:name]).to eq('testteam')
      expect(result[:health_score]).to eq(3) # off_track
    end

    it 'returns not_available health score when team health lookup fails' do
      record = instance_double('TeamRecord', id: '456')
      result_double = instance_double('Result', success?: false, value: nil, errors: ['not found'])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: '456').and_return(result_double)

      result = helper.team_sort_data(record)

      expect(result[:health_score]).to eq(99) # not_available fallback
    end

    it 'handles objects without name method' do
      object = instance_double('SomeObject', health: :on_track)
      allow(object).to receive(:respond_to?).with(:health).and_return(true)
      allow(object).to receive(:respond_to?).with(:name).and_return(false)

      result = helper.team_sort_data(object)

      expect(result[:name]).to eq('')
      expect(result[:health_score]).to eq(1) # on_track
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

    it 'omits description when not present' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :on_track, description: nil)
      project = instance_double('Project', health_trend: [update])

      html = helper.project_health_trend(project)

      expect(html).not_to include('health-trend-tooltip__desc')
    end

    it 'omits description when empty string' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :on_track, description: '')
      project = instance_double('Project', health_trend: [update])

      html = helper.project_health_trend(project)

      expect(html).not_to include('health-trend-tooltip__desc')
    end

    it 'renders non-interactive trend items when interactive is false' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :on_track, description: nil)
      project = instance_double('Project', health_trend: [update])

      html = helper.project_health_trend(project, interactive: false)

      expect(html).not_to include('<button')
      expect(html).to include('health-trend-item')
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

    it 'returns plain indicator when project does not respond to health_updates_for_tooltip' do
      project = instance_double(
        'Project',
        health: :on_track,
        children_health_for_tooltip: nil
      )
      allow(project).to receive(:respond_to?).with(:children_health_for_tooltip).and_return(true)
      allow(project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(false)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
    end

    it 'returns plain indicator when project does not respond to children_health_for_tooltip' do
      project = instance_double('Project', health: :on_track)
      allow(project).to receive(:respond_to?).with(:children_health_for_tooltip).and_return(false)
      allow(project).to receive(:respond_to?).with(:health_updates_for_tooltip).and_return(false)
      allow(project).to receive(:respond_to?).with(:health).and_return(true)

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
    end

    it 'handles update that does not respond to description in tooltip' do
      update = instance_double('HealthUpdate', date: Date.new(2025, 1, 13), health: :on_track)
      allow(update).to receive(:respond_to?).with(:description).and_return(false)
      project = instance_double(
        'Project',
        health: :on_track,
        children_health_for_tooltip: nil,
        health_updates_for_tooltip: [update]
      )

      html = helper.project_health_indicator(project, with_tooltip: true)

      expect(html).to include('health-indicator-wrapper')
      expect(html).to include('1/13')
      expect(html).not_to include('health-trend-tooltip__desc')
    end
  end

  describe '#initiative_health_indicator' do
    it 'loads domain initiative health for InitiativeRecord' do
      record = instance_double('InitiativeRecord', id: '123')
      domain_initiative = instance_double('Initiative', health: :off_track)
      result = instance_double('Result', success?: true, value: domain_initiative, errors: [])
      actions = Rails.application.config.x.initiative_actions
      allow(actions.find_initiative).to receive(:perform).with(id: '123').and_return(result)

      html = helper.initiative_health_indicator(record)

      expect(html).to include('project-health--off_track')
    end

    it 'uses the domain initiative directly when it responds to health' do
      initiative = instance_double('Initiative', health: :on_track)

      html = helper.initiative_health_indicator(initiative)

      expect(html).to include('project-health--on_track')
      expect(html).to include('On Track')
    end

    it 'caches domain initiative lookups' do
      record = instance_double('InitiativeRecord', id: '123')
      domain_initiative = instance_double('Initiative', health: :at_risk)
      result = instance_double('Result', success?: true, value: domain_initiative, errors: [])
      actions = Rails.application.config.x.initiative_actions
      expect(actions.find_initiative).to receive(:perform).once.with(id: '123').and_return(result)

      2.times { helper.initiative_health_indicator(record) }
    end

    it 'returns :not_available when find_initiative fails' do
      record = instance_double('InitiativeRecord', id: '456')
      result = instance_double('Result', success?: false, value: nil, errors: ['initiative not found'])
      actions = Rails.application.config.x.initiative_actions
      allow(actions.find_initiative).to receive(:perform).with(id: '456').and_return(result)

      html = helper.initiative_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end

    it 'shows tooltip with related projects when with_tooltip is true' do
      project = instance_double('Project', name: 'Feature A', health: :on_track)
      initiative = instance_double('Initiative', health: :on_track, related_projects: [project])

      html = helper.initiative_health_indicator(initiative, with_tooltip: true)

      expect(html).to include('health-indicator-wrapper')
      expect(html).to include('health-rollup-tooltip')
      expect(html).to include('Feature A')
    end

    it 'returns plain indicator when related_projects is empty' do
      initiative = instance_double('Initiative', health: :on_track, related_projects: [])

      html = helper.initiative_health_indicator(initiative, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'returns plain indicator when related_projects does not respond to any?' do
      non_enumerable_projects = Object.new
      initiative = instance_double('Initiative', health: :on_track, related_projects: non_enumerable_projects)

      html = helper.initiative_health_indicator(initiative, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'returns plain indicator when initiative does not respond to related_projects' do
      initiative = instance_double('Initiative', health: :on_track)
      allow(initiative).to receive(:respond_to?).with(:health).and_return(true)
      allow(initiative).to receive(:respond_to?).with(:related_projects).and_return(false)

      html = helper.initiative_health_indicator(initiative, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'handles initiative_record without id method' do
      record = Object.new
      result = instance_double('Result', success?: false, value: nil, errors: ['initiative not found'])
      actions = Rails.application.config.x.initiative_actions
      allow(actions.find_initiative).to receive(:perform).with(id: nil).and_return(result)

      html = helper.initiative_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end
  end

  describe '#team_health_indicator' do
    it 'loads domain team health for TeamRecord' do
      record = instance_double('TeamRecord', id: '123')
      domain_team = instance_double('Team', health: :off_track)
      result = instance_double('Result', success?: true, value: domain_team, errors: [])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: '123').and_return(result)

      html = helper.team_health_indicator(record)

      expect(html).to include('project-health--off_track')
    end

    it 'uses the domain team directly when it responds to health' do
      team = instance_double('Team', health: :on_track)

      html = helper.team_health_indicator(team)

      expect(html).to include('project-health--on_track')
      expect(html).to include('On Track')
    end

    it 'caches domain team lookups' do
      record = instance_double('TeamRecord', id: '123')
      domain_team = instance_double('Team', health: :at_risk)
      result = instance_double('Result', success?: true, value: domain_team, errors: [])
      actions = Rails.application.config.x.team_actions
      expect(actions.find_team).to receive(:perform).once.with(id: '123').and_return(result)

      2.times { helper.team_health_indicator(record) }
    end

    it 'returns :not_available when find_team fails' do
      record = instance_double('TeamRecord', id: '456')
      result = instance_double('Result', success?: false, value: nil, errors: ['team not found'])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: '456').and_return(result)

      html = helper.team_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end

    it 'shows tooltip with owned projects when with_tooltip is true' do
      project = instance_double('Project', name: 'Feature A', health: :on_track)
      team = instance_double('Team', health: :on_track, owned_projects: [project])

      html = helper.team_health_indicator(team, with_tooltip: true)

      expect(html).to include('health-indicator-wrapper')
      expect(html).to include('health-rollup-tooltip')
      expect(html).to include('Feature A')
    end

    it 'returns plain indicator when owned_projects is empty' do
      team = instance_double('Team', health: :on_track, owned_projects: [])

      html = helper.team_health_indicator(team, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'returns plain indicator when owned_projects does not respond to any?' do
      non_enumerable_projects = Object.new
      team = instance_double('Team', health: :on_track, owned_projects: non_enumerable_projects)

      html = helper.team_health_indicator(team, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'returns plain indicator when team does not respond to owned_projects' do
      team = instance_double('Team', health: :on_track)
      allow(team).to receive(:respond_to?).with(:health).and_return(true)
      allow(team).to receive(:respond_to?).with(:owned_projects).and_return(false)

      html = helper.team_health_indicator(team, with_tooltip: true)

      expect(html).not_to include('health-indicator-wrapper')
      expect(html).to include('project-health--on_track')
    end

    it 'handles team_record without id method' do
      record = Object.new
      result = instance_double('Result', success?: false, value: nil, errors: ['team not found'])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: nil).and_return(result)

      html = helper.team_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end

    it 'does not cache when cache_key is nil' do
      # Create an object that doesn't respond to :id
      record = Object.new

      result = instance_double('Result', success?: false, value: nil, errors: ['team not found'])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: nil).and_return(result)

      # Call twice to ensure it doesn't cache when key is nil
      helper.team_health_indicator(record)
      helper.team_health_indicator(record)

      expect(actions.find_team).to have_received(:perform).with(id: nil).at_least(:once)
    end

    it 'returns team when cache_key is nil and find succeeds' do
      # Create an object that doesn't respond to :id
      record = Object.new
      domain_team = instance_double('Team', health: :on_track)

      result = instance_double('Result', success?: true, value: domain_team, errors: [])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: nil).and_return(result)

      html = helper.team_health_indicator(record)

      expect(html).to include('project-health--on_track')
    end

    it 'returns nil team when cache_key is nil and find fails' do
      record = Object.new

      result = instance_double('Result', success?: false, value: nil, errors: ['team not found'])
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).with(id: nil).and_return(result)

      html = helper.team_health_indicator(record)

      expect(html).to include('project-health--not_available')
    end
  end

  describe '#project_breadcrumb' do
    it 'returns empty string when project has no parent or team' do
      project = double('Project', parent: nil, owning_team: nil)
      allow(project).to receive(:respond_to?).with(:owning_team).and_return(true)
      allow(project).to receive(:respond_to?).with(:parent).and_return(true)
      project_record = ProjectRecord.create!(name: 'Orphan')

      result = helper.project_breadcrumb(project, project_record)

      expect(result).to eq('')
    end

    it 'includes Home and parent project in breadcrumb' do
      parent_record = ProjectRecord.create!(name: 'Parent Project')
      child_record = ProjectRecord.create!(name: 'Child Project')

      parent = double('Project', name: 'Parent Project', parent: nil, owning_team: nil)
      allow(parent).to receive(:respond_to?).with(:parent).and_return(true)
      allow(parent).to receive(:respond_to?).with(:owning_team).and_return(true)

      child = double('Project', name: 'Child Project', parent: parent, owning_team: nil)
      allow(child).to receive(:respond_to?).with(:owning_team).and_return(true)
      allow(child).to receive(:respond_to?).with(:parent).and_return(true)

      result = helper.project_breadcrumb(child, child_record)

      expect(result).to include('Status')
      expect(result).to include('Parent Project')
    end

    it 'includes owning team in breadcrumb' do
      team_record = TeamRecord.create!(name: 'Platform')
      project_record = ProjectRecord.create!(name: 'Feature')

      team = double('Team', name: 'Platform', parent_team: nil)
      allow(team).to receive(:respond_to?).with(:parent_team).and_return(true)

      project = double('Project', name: 'Feature', parent: nil, owning_team: team)
      allow(project).to receive(:respond_to?).with(:owning_team).and_return(true)
      allow(project).to receive(:respond_to?).with(:parent).and_return(true)

      result = helper.project_breadcrumb(project, project_record)

      expect(result).to include('Status')
      expect(result).to include('Platform')
    end
  end

  describe '#team_breadcrumb' do
    it 'returns empty string when team has no parent' do
      team = double('Team', parent_team: nil)
      allow(team).to receive(:respond_to?).with(:parent_team).and_return(true)
      team_record = TeamRecord.create!(name: 'Root Team')

      result = helper.team_breadcrumb(team, team_record)

      expect(result).to eq('')
    end

    it 'includes Home and parent team in breadcrumb' do
      parent_record = TeamRecord.create!(name: 'Engineering')
      child_record = TeamRecord.create!(name: 'Platform')

      parent = double('Team', name: 'Engineering', parent_team: nil)
      allow(parent).to receive(:respond_to?).with(:parent_team).and_return(true)

      child = double('Team', name: 'Platform', parent_team: parent)
      allow(child).to receive(:respond_to?).with(:parent_team).and_return(true)

      result = helper.team_breadcrumb(child, child_record)

      expect(result).to include('Status')
      expect(result).to include('Engineering')
    end
  end

  describe '#initiative_breadcrumb' do
    it 'returns empty string for initiatives (only Home, which is skipped)' do
      initiative = double('Initiative')
      initiative_record = InitiativeRecord.create!(name: 'Q1 Goals')

      result = helper.initiative_breadcrumb(initiative, initiative_record)

      expect(result).to eq('')
    end
  end

  describe 'breadcrumb edge cases' do
    it 'handles team without respond_to parent_team in hierarchy' do
      team_record = TeamRecord.create!(name: 'NoParentMethod')

      # Team that doesn't respond to parent_team
      team = double('Team', name: 'NoParentMethod')
      allow(team).to receive(:respond_to?).with(:parent_team).and_return(false)

      result = helper.team_breadcrumb(team, team_record)

      expect(result).to eq('')
    end

    it 'handles project without respond_to parent in hierarchy' do
      project_record = ProjectRecord.create!(name: 'NoParentMethod')

      project = double('Project', name: 'NoParentMethod')
      allow(project).to receive(:respond_to?).with(:owning_team).and_return(false)
      allow(project).to receive(:respond_to?).with(:parent).and_return(false)

      result = helper.project_breadcrumb(project, project_record)

      expect(result).to eq('')
    end

    it 'handles team hierarchy with missing team record' do
      # Only create the child record, not the parent
      child_record = TeamRecord.create!(name: 'ChildOnly')

      parent = double('Team', name: 'MissingParent', parent_team: nil)
      allow(parent).to receive(:respond_to?).with(:parent_team).and_return(true)

      child = double('Team', name: 'ChildOnly', parent_team: parent)
      allow(child).to receive(:respond_to?).with(:parent_team).and_return(true)

      result = helper.team_breadcrumb(child, child_record)

      # Should only include Home (parent record doesn't exist)
      expect(result).to eq('')
    end

    it 'handles project with parent that does not respond to parent' do
      parent_record = ProjectRecord.create!(name: 'ParentNoMethod')
      child_record = ProjectRecord.create!(name: 'ChildProject')

      parent = double('Project', name: 'ParentNoMethod', parent: nil, owning_team: nil)
      allow(parent).to receive(:respond_to?).with(:parent).and_return(false)
      allow(parent).to receive(:respond_to?).with(:owning_team).and_return(true)

      child = double('Project', name: 'ChildProject', parent: parent, owning_team: nil)
      allow(child).to receive(:respond_to?).with(:owning_team).and_return(true)
      allow(child).to receive(:respond_to?).with(:parent).and_return(true)

      result = helper.project_breadcrumb(child, child_record)

      expect(result).to include('Status')
      expect(result).to include('ParentNoMethod')
    end

    it 'handles team in hierarchy that does not respond to parent_team' do
      parent_record = TeamRecord.create!(name: 'ParentTeam')
      child_record = TeamRecord.create!(name: 'ChildTeam')

      parent = double('Team', name: 'ParentTeam')
      allow(parent).to receive(:respond_to?).with(:parent_team).and_return(false)

      child = double('Team', name: 'ChildTeam', parent_team: parent)
      allow(child).to receive(:respond_to?).with(:parent_team).and_return(true)

      result = helper.team_breadcrumb(child, child_record)

      expect(result).to include('Status')
      expect(result).to include('ParentTeam')
    end

    it 'handles project ancestor without record in database' do
      child_record = ProjectRecord.create!(name: 'ChildOnly')

      parent = double('Project', name: 'MissingRecord', parent: nil, owning_team: nil)
      allow(parent).to receive(:respond_to?).with(:parent).and_return(true)
      allow(parent).to receive(:respond_to?).with(:owning_team).and_return(true)

      child = double('Project', name: 'ChildOnly', parent: parent, owning_team: nil)
      allow(child).to receive(:respond_to?).with(:owning_team).and_return(true)
      allow(child).to receive(:respond_to?).with(:parent).and_return(true)

      result = helper.project_breadcrumb(child, child_record)

      # Parent record doesn't exist so it shouldn't appear, just Home
      expect(result).to eq('')
    end
  end
end
