require 'rails_helper'

RSpec.describe DashboardController, type: :request do
  describe 'GET /' do
    it 'renders the dashboard' do
      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Active Projects')
    end

    it 'shows health summary stats' do
      project = ProjectRecord.create!(name: 'Test Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project, date: Date.current, health: 'on_track')

      get '/'

      expect(response.body).to include('On Track')
    end

    it 'shows attention required section' do
      project = ProjectRecord.create!(name: 'Problem Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project, date: Date.current, health: 'off_track')

      get '/'

      expect(response.body).to include('Needs Attention')
      expect(response.body).to include('Problem Project')
    end

    it 'shows congratulations message when needs attention is empty' do
      get '/'

      expect(response.body).to include('Needs Attention')
      expect(response.body).to include('Everything is on track!')
    end

    it 'shows on hold projects section' do
      ProjectRecord.create!(name: 'On Hold Project', current_state: 'on_hold')

      get '/'

      expect(response.body).to include('On Hold')
      expect(response.body).to include('On Hold Project')
    end

    it 'shows never updated projects section' do
      ProjectRecord.create!(name: 'Never Updated Project', current_state: 'in_progress')

      get '/'

      expect(response.body).to include('Stale')
      expect(response.body).to include('Never Updated')
      expect(response.body).to include('Never Updated Project')
    end

    it 'shows stale projects in 14+ days section' do
      project = ProjectRecord.create!(name: 'Very Stale Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project, date: Date.current - 20, health: 'on_track')

      get '/'

      expect(response.body).to include('Stale')
      expect(response.body).to include('Not Updated in 14+ Days')
      expect(response.body).to include('Very Stale Project')
    end

    it 'shows stale projects in 7+ days section' do
      project = ProjectRecord.create!(name: 'Somewhat Stale Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project, date: Date.current - 10, health: 'on_track')

      get '/'

      expect(response.body).to include('Stale')
      expect(response.body).to include('Not Updated in 7+ Days')
      expect(response.body).to include('Somewhat Stale Project')
    end

    it 'shows orphan projects section' do
      ProjectRecord.create!(name: 'Orphan Project', current_state: 'in_progress')

      get '/'

      expect(response.body).to include('Unowned Project')
      expect(response.body).to include('Orphan Project')
    end

    it 'shows quick links to other pages' do
      get '/'

      expect(response.body).to include('Projects')
      expect(response.body).to include('Teams')
      expect(response.body).to include('Initiatives')
    end

    it 'shows at_risk system health when health is mixed' do
      # Create 3 projects: one on_track, one at_risk, one off_track
      # This gives a score of (1 + 0 + -1) / 3 = 0, which is :at_risk
      project_a = ProjectRecord.create!(name: 'On Track Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project_a, date: Date.current, health: 'on_track')

      project_b = ProjectRecord.create!(name: 'At Risk Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project_b, date: Date.current, health: 'at_risk')

      project_c = ProjectRecord.create!(name: 'Off Track Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project_c, date: Date.current, health: 'off_track')

      get '/'

      expect(response.body).to include('At Risk')
    end

    it 'shows teams column with health indicators' do
      team = TeamRecord.create!(name: 'Alpha Team')
      project = ProjectRecord.create!(name: 'Team Project', current_state: 'in_progress')
      TeamsProjectRecord.create!(team: team, project: project, order: 1)
      HealthUpdateRecord.create!(project: project, date: Date.current, health: 'on_track')

      get '/'

      expect(response.body).to include('Teams')
      expect(response.body).to include('Alpha Team')
      expect(response.body).to include('project-item-v2__health')
    end

    it 'shows only top-level teams in teams column' do
      parent_team = TeamRecord.create!(name: 'Parent Team')
      child_team = TeamRecord.create!(name: 'Child Team')
      TeamsTeamRecord.create!(parent: parent_team, child: child_team, order: 0)

      get '/'

      # Parent team should be in teams column, child team only in search results
      expect(response.body).to include('Parent Team')
      expect(response.body.scan('Child Team').count).to eq(1) # Only in global search
    end

    it 'shows global search for teams, initiatives, and projects' do
      TeamRecord.create!(name: 'Search Team', point_of_contact: 'team-poc@example.com')
      InitiativeRecord.create!(name: 'Search Initiative', point_of_contact: 'init-poc@example.com')
      ProjectRecord.create!(name: 'Search Project', current_state: 'in_progress', point_of_contact: 'proj-poc@example.com')

      get '/'

      expect(response.body).to include('data-global-search')
      expect(response.body).to include('global-search__results')
      expect(response.body).to include('Search Team')
      expect(response.body).to include('Search Initiative')
      expect(response.body).to include('Search Project')
      expect(response.body).to include('team-poc@example.com')
      expect(response.body).to include('init-poc@example.com')
      expect(response.body).to include('proj-poc@example.com')
    end

    it 'shows create project form in global search when no results' do
      get '/'

      expect(response.body).to include('global-search__create-btn')
      expect(response.body).to include('Create Project')
      expect(response.body).to include('global-search__results-header')
      expect(response.body).to include('project[name]')
      expect(response.body).to include('project[description]')
      expect(response.body).to include('project[point_of_contact]')
    end

    it 'shows initiatives column with health indicators' do
      initiative = InitiativeRecord.create!(name: 'Beta Initiative')
      project = ProjectRecord.create!(name: 'Initiative Project', current_state: 'in_progress')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 1)
      HealthUpdateRecord.create!(project: project, date: Date.current, health: 'on_track')

      get '/'

      expect(response.body).to include('Initiatives')
      expect(response.body).to include('Beta Initiative')
      expect(response.body).to include('project-item-v2__health')
    end
  end
end
