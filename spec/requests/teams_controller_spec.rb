require 'rails_helper'

RSpec.describe TeamsController, type: :request do
  let(:actions) { Rails.application.config.x.team_actions }
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'HTML endpoints' do
    it 'renders the index' do
      TeamRecord.create!(name: 'Platform Team')

      get '/teams'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Platform Team')
    end

    it 'renders a health indicator for teams on the index' do
      TeamRecord.create!(name: 'Platform Team')

      get '/teams'

      expect(response.body).to include('metric-widget--health')
    end

    it 'sorts teams alphabetically by default' do
      TeamRecord.create!(name: 'Zeta Team')
      TeamRecord.create!(name: 'Alpha Team')

      get '/teams'

      list_section = response.body[/teams-index__list.*$/m]
      alpha_index = list_section.index('Alpha Team')
      zeta_index = list_section.index('Zeta Team')
      expect(alpha_index).to be < zeta_index
    end

    it 'sorts teams alphabetically descending when requested' do
      TeamRecord.create!(name: 'Zeta Team')
      TeamRecord.create!(name: 'Alpha Team')

      get '/teams?sort=alphabet&dir=desc'

      list_section = response.body[/teams-index__list.*$/m]
      alpha_index = list_section.index('Alpha Team')
      zeta_index = list_section.index('Zeta Team')
      expect(zeta_index).to be < alpha_index
    end

    it 'sorts teams by health ascending (best to worst)' do
      on_track_team = TeamRecord.create!(name: 'On Track Team')
      off_track_team = TeamRecord.create!(name: 'Off Track Team')
      TeamRecord.create!(name: 'No Health Team')
      on_track_proj = ProjectRecord.create!(name: 'On Track Project', current_state: 'in_progress')
      off_track_proj = ProjectRecord.create!(name: 'Off Track Project', current_state: 'in_progress')
      TeamsProjectRecord.create!(team: on_track_team, project: on_track_proj, order: 0)
      TeamsProjectRecord.create!(team: off_track_team, project: off_track_proj, order: 0)
      HealthUpdateRecord.create!(project: on_track_proj, date: Date.today, health: 'on_track')
      HealthUpdateRecord.create!(project: off_track_proj, date: Date.today, health: 'off_track')

      get '/teams?sort=health&dir=asc'

      list_section = response.body[/teams-index__list.*$/m]
      on_track_index = list_section.index('On Track Team')
      off_track_index = list_section.index('Off Track Team')
      no_health_index = list_section.index('No Health Team')
      expect(on_track_index).to be < off_track_index
      expect(off_track_index).to be < no_health_index
    end

    it 'sorts teams by health descending (worst to best, no health last)' do
      on_track_team = TeamRecord.create!(name: 'On Track Team')
      off_track_team = TeamRecord.create!(name: 'Off Track Team')
      TeamRecord.create!(name: 'No Health Team')
      on_track_proj = ProjectRecord.create!(name: 'On Track Project', current_state: 'in_progress')
      off_track_proj = ProjectRecord.create!(name: 'Off Track Project', current_state: 'in_progress')
      TeamsProjectRecord.create!(team: on_track_team, project: on_track_proj, order: 0)
      TeamsProjectRecord.create!(team: off_track_team, project: off_track_proj, order: 0)
      HealthUpdateRecord.create!(project: on_track_proj, date: Date.today, health: 'on_track')
      HealthUpdateRecord.create!(project: off_track_proj, date: Date.today, health: 'off_track')

      get '/teams?sort=health&dir=desc'

      list_section = response.body[/teams-index__list.*$/m]
      on_track_index = list_section.index('On Track Team')
      off_track_index = list_section.index('Off Track Team')
      no_health_index = list_section.index('No Health Team')
      expect(off_track_index).to be < on_track_index
      expect(on_track_index).to be < no_health_index
    end

    it 'sorts archived teams last when sorting by health' do
      TeamRecord.create!(name: 'Active Team')
      TeamRecord.create!(name: 'Archived Team', archived: true)

      get '/teams?sort=health&dir=asc'

      active_index = response.body.index('Active Team')
      archived_index = response.body.index('Archived Team')
      expect(active_index).to be < archived_index
    end

    it 'ignores invalid sort parameters' do
      TeamRecord.create!(name: 'Test Team')

      get '/teams?sort=invalid'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test Team')
    end

    it 'treats teams with failed health lookup as not_available when sorting by health' do
      team = TeamRecord.create!(name: 'Test Team')
      actions = Rails.application.config.x.team_actions
      find_action = actions.find_team

      allow(find_action).to receive(:perform).and_call_original
      allow(find_action).to receive(:perform).with(id: team.id).and_return(
        Result.failure(errors: 'team not found')
      )

      get '/teams?sort=health&dir=asc'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test Team')
    end

    it 'renders the show page' do
      record = TeamRecord.create!(name: 'Platform Team')

      get "/teams/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Platform Team')
    end

    it 'renders a health indicator for the team on the show page' do
      record = TeamRecord.create!(name: 'Platform Team')

      get "/teams/#{record.id}"

      expect(response.body).to include('metric-widget--health')
    end

    it 'links owned projects to their show pages with team ref' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = ProjectRecord.create!(name: 'Feature A')
      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      get "/teams/#{team.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="/projects/#{project.id}?ref=team%3A#{team.id}"))
      expect(response.body).to include('Feature A')
    end

    it 'creates via HTML and redirects' do
      post '/teams', params: { team: { name: 'Platform Team' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Platform Team')
    end

    it 'creates via HTML with all params' do
      post '/teams', params: {
        team: { name: 'Full Team', mission: 'M', vision: 'V', point_of_contact: 'POC' }
      }

      expect(response).to have_http_status(:found)
      record = TeamRecord.find_by(name: 'Full Team')
      expect(record.mission).to eq('M')
      expect(record.vision).to eq('V')
      expect(record.point_of_contact).to eq('POC')
    end

    it 'renders validation errors on HTML create' do
      post '/teams', params: { team: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'updates via HTML and redirects' do
      record = TeamRecord.create!(name: 'Platform Team')

      patch "/teams/#{record.id}", params: { team: { name: 'Infra Team' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Infra Team')
    end

    it 'renders validation errors on HTML update' do
      record = TeamRecord.create!(name: 'Platform Team')

      patch "/teams/#{record.id}", params: { team: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'archives via HTML and redirects' do
      record = TeamRecord.create!(name: 'Platform Team')

      patch "/teams/#{record.id}/archive"

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('archived')
    end

    it 'returns 404 for missing team in HTML archive' do
      patch '/teams/999/archive'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for missing team in HTML show' do
      get '/teams/999'

      expect(response).to have_http_status(:not_found)
    end

    it 'creates and adds a new owned project via HTML' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: 'New Feature' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('New Feature')
      expect(ProjectRecord.find_by(name: 'New Feature')).to be_present
    end

    it 'returns error when add_owned_project fails' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'handles nil domain team when add_owned_project fails' do
      team = TeamRecord.create!(name: 'Platform Team')
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).and_return(Result.failure(errors: 'team not found'))

      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns error when project created but linking fails' do
      team = TeamRecord.create!(name: 'Platform Team')
      child_team = TeamRecord.create!(name: 'Child Team')
      TeamsTeamRecord.create!(parent: team, child: child_team, order: 0)

      # Team has subordinate teams, so linking will fail
      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: 'New Feature' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('teams with subordinate teams cannot own projects')
    end

    it 'creates a subordinate team via HTML and redirects to the new team' do
      parent = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{parent.id}/subordinate_teams", params: { team: { name: 'Mobile Team' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Mobile Team')
      expect(TeamRecord.find_by(name: 'Mobile Team')).to be_present
    end

    it 'creates a subordinate team with all attributes via HTML' do
      parent = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{parent.id}/subordinate_teams", params: {
        team: { name: 'Mobile Team', mission: 'Build apps', vision: 'Be mobile', point_of_contact: 'mobile@test.com' }
      }

      expect(response).to have_http_status(:found)
      record = TeamRecord.find_by(name: 'Mobile Team')
      expect(record.mission).to eq('Build apps')
      expect(record.vision).to eq('Be mobile')
      expect(record.point_of_contact).to eq('mobile@test.com')
    end

    it 'creates an owned project with all attributes via HTML' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add", params: {
        project: { name: 'New Feature', description: 'Desc', point_of_contact: 'poc@test.com' }
      }

      expect(response).to have_http_status(:found)
      record = ProjectRecord.find_by(name: 'New Feature')
      expect(record.description).to eq('Desc')
      expect(record.point_of_contact).to eq('poc@test.com')
    end

    it 'returns error when add_subordinate_team fails' do
      parent = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{parent.id}/subordinate_teams", params: { team: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'handles nil domain team when add_subordinate_team fails' do
      parent = TeamRecord.create!(name: 'Platform Team')
      actions = Rails.application.config.x.team_actions
      allow(actions.find_team).to receive(:perform).and_return(Result.failure(errors: 'team not found'))

      post "/teams/#{parent.id}/subordinate_teams", params: { team: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /teams.json' do
    it 'lists teams as JSON' do
      TeamRecord.create!(name: 'Platform Team')

      get '/teams.json'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |t| t['name'] }).to include('Platform Team')
    end
  end

  describe 'POST /teams' do
    it 'creates a team' do
      post '/teams', params: { team: { name: 'Platform Team', mission: 'Build', vision: 'Scale' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Platform Team')
    end

    it 'returns errors for invalid team' do
      post '/teams', params: { team: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end

  describe 'GET /teams/:id' do
    it 'shows a team' do
      record = TeamRecord.create!(name: 'Platform Team')

      get "/teams/#{record.id}", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Platform Team')
    end

    it 'returns 404 when not found' do
      get '/teams/999999', headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /teams/:id' do
    it 'updates a team' do
      record = TeamRecord.create!(name: 'Platform Team')

      patch "/teams/#{record.id}", params: { team: { name: 'Infra Team' } }, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Infra Team')
    end

    it 'returns errors for invalid update' do
      record = TeamRecord.create!(name: 'Platform Team')

      patch "/teams/#{record.id}", params: { team: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end

  describe 'PATCH /teams/:id/archive' do
    it 'archives a team' do
      record = TeamRecord.create!(name: 'Platform Team')

      patch "/teams/#{record.id}/archive", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['archived']).to eq(true)
    end

    it 'returns 404 when team is missing' do
      patch '/teams/999/archive', headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /teams/:id/owned_projects/add' do
    it 'creates and links a new owned project' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: 'New Feature' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('New Feature')
      expect(TeamsProjectRecord.where(team: team).count).to eq(1)
    end

    it 'returns error for invalid project' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end

    it 'returns 404 when team not found' do
      post '/teams/999/owned_projects/add', params: { project: { name: 'Feature' } }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /teams/:id/owned_projects (link)' do
    it 'links an existing project to a team' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = ProjectRecord.create!(name: 'Existing Project')

      post "/teams/#{team.id}/owned_projects", params: { project_id: project.id }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Existing Project')
      expect(TeamsProjectRecord.where(team: team, project: project).count).to eq(1)
    end

    it 'returns 404 when project not found' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects", params: { project_id: 999 }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when team not found' do
      project = ProjectRecord.create!(name: 'Existing Project')

      post '/teams/999/owned_projects', params: { project_id: project.id }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'links an existing project via HTML and redirects' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = ProjectRecord.create!(name: 'Existing Project')

      post "/teams/#{team.id}/owned_projects", params: { project_id: project.id }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Existing Project')
    end

    it 'returns 404 for missing project via HTML' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects", params: { project_id: 999 }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /teams/:id/subordinate_teams' do
    it 'creates a subordinate team' do
      parent = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{parent.id}/subordinate_teams", params: { team: { name: 'Mobile Team' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Mobile Team')
      expect(TeamsTeamRecord.where(parent: parent).count).to eq(1)
    end

    it 'returns error for invalid subordinate team' do
      parent = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{parent.id}/subordinate_teams", params: { team: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end

    it 'returns 404 when parent not found' do
      post '/teams/999/subordinate_teams', params: { team: { name: 'Sub Team' } }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error for duplicate team name' do
      parent = TeamRecord.create!(name: 'Platform Team')
      TeamRecord.create!(name: 'Existing Team')

      post "/teams/#{parent.id}/subordinate_teams", params: { team: { name: 'Existing Team' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('team name must be unique')
    end
  end
end
