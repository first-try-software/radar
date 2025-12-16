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
      expect(response.body).to include('home-column__health')
    end

    it 'shows initiatives column with health indicators' do
      initiative = InitiativeRecord.create!(name: 'Beta Initiative')
      project = ProjectRecord.create!(name: 'Initiative Project', current_state: 'in_progress')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 1)
      HealthUpdateRecord.create!(project: project, date: Date.current, health: 'on_track')

      get '/'

      expect(response.body).to include('Initiatives')
      expect(response.body).to include('Beta Initiative')
      expect(response.body).to include('home-column__health')
    end
  end
end
