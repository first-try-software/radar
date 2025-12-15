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

      expect(response.body).to include('Needs Update')
      expect(response.body).to include('NEVER UPDATED')
      expect(response.body).to include('Never Updated Project')
    end

    it 'shows stale projects in 14+ days section' do
      project = ProjectRecord.create!(name: 'Very Stale Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project, date: Date.current - 20, health: 'on_track')

      get '/'

      expect(response.body).to include('Needs Update')
      expect(response.body).to include('NOT UPDATED IN 14+ DAYS')
      expect(response.body).to include('Very Stale Project')
    end

    it 'shows stale projects in 7+ days section' do
      project = ProjectRecord.create!(name: 'Somewhat Stale Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project, date: Date.current - 10, health: 'on_track')

      get '/'

      expect(response.body).to include('Needs Update')
      expect(response.body).to include('NOT UPDATED IN 7+ DAYS')
      expect(response.body).to include('Somewhat Stale Project')
    end

    it 'shows orphan projects section' do
      ProjectRecord.create!(name: 'Orphan Project', current_state: 'in_progress')

      get '/'

      expect(response.body).to include('Needs Owner')
      expect(response.body).to include('Orphan Project')
    end

    it 'shows quick links to other pages' do
      get '/'

      expect(response.body).to include('Projects')
      expect(response.body).to include('Teams')
      expect(response.body).to include('Initiatives')
    end
  end
end
