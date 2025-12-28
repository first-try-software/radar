require 'rails_helper'

RSpec.describe TeamsController, type: :request do
  let(:actions) { Rails.application.config.x.team_actions }
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }
  let(:turbo_stream_headers) { { 'ACCEPT' => 'text/vnd.turbo-stream.html' } }

  describe 'HTML endpoints' do
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
      expect(response.body).to include(%(href="/projects/#{project.id}"))
      expect(response.body).to include('Feature A')
    end

    it 'includes nested subordinate teams in search data' do
      parent = TeamRecord.create!(name: 'Platform Team')
      child = TeamRecord.create!(name: 'Mobile Team')
      grandchild = TeamRecord.create!(name: 'iOS Team')
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)
      TeamsTeamRecord.create!(parent: child, child: grandchild, order: 0)

      get "/teams/#{parent.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Platform Team')
      expect(response.body).to include('Mobile Team')
      expect(response.body).to include('iOS Team')
    end

    it 'includes initiatives in search data' do
      team = TeamRecord.create!(name: 'Platform Team')
      InitiativeRecord.create!(name: 'Q1 Launch')

      get "/teams/#{team.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Q1 Launch')
    end

    it 'creates via HTML and redirects' do
      post '/teams', params: { team: { name: 'Platform Team' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Platform Team')
    end

    it 'creates via HTML with all params' do
      post '/teams', params: {
        team: { name: 'Full Team', description: 'D', point_of_contact: 'POC' }
      }

      expect(response).to have_http_status(:found)
      record = TeamRecord.find_by(name: 'Full Team')
      expect(record.description).to eq('D')
      expect(record.point_of_contact).to eq('POC')
    end

    it 'redirects with error on HTML create failure' do
      post '/teams', params: { team: { name: '' } }

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(root_path)
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

    it 'returns 404 on HTML update when team disappears mid-request' do
      record = TeamRecord.create!(name: 'Platform Team')
      allow_any_instance_of(UpdateTeam).to receive(:perform).and_return(Result.failure(errors: ['update failed']))
      allow_any_instance_of(FindTeam).to receive(:perform).and_return(Result.failure(errors: ['team not found']))

      patch "/teams/#{record.id}", params: { team: { name: 'New Name' } }

      expect(response).to have_http_status(:not_found)
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

      expect(response).to have_http_status(:not_found)
    end

    it 'allows teams with subordinate teams to own projects' do
      team = TeamRecord.create!(name: 'Platform Team')
      child_team = TeamRecord.create!(name: 'Child Team')
      TeamsTeamRecord.create!(parent: team, child: child_team, order: 0)

      post "/teams/#{team.id}/owned_projects/add", params: { project: { name: 'New Feature' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('New Feature')
    end

    it 'returns error when linking a child project' do
      team = TeamRecord.create!(name: 'Platform Team')
      parent_project = ProjectRecord.create!(name: 'Parent Project')
      child_project = ProjectRecord.create!(name: 'Child Project')
      ProjectsProjectRecord.create!(parent: parent_project, child: child_project, order: 0)

      post "/teams/#{team.id}/owned_projects", params: { project_id: child_project.id }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('only top-level projects can be owned by teams')
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
        team: { name: 'Mobile Team', description: 'Build mobile apps', point_of_contact: 'mobile@test.com' }
      }

      expect(response).to have_http_status(:found)
      record = TeamRecord.find_by(name: 'Mobile Team')
      expect(record.description).to eq('Build mobile apps')
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

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /teams' do
    it 'creates a team' do
      post '/teams', params: { team: { name: 'Platform Team', description: 'Build and Scale' } }, headers: json_headers

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

  describe 'turbo_stream endpoints' do
    it 'creates an owned project via turbo_stream' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add",
           params: { project: { name: 'TurboProject' } },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(ProjectRecord.exists?(name: 'TurboProject')).to be(true)
    end

    it 'returns turbo_stream error for invalid owned project' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects/add",
           params: { project: { name: '' } },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'links an existing project via turbo_stream' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = ProjectRecord.create!(name: 'ExistingProject')

      post "/teams/#{team.id}/owned_projects",
           params: { project_id: project.id },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(TeamsProjectRecord.exists?(team: team, project: project)).to be(true)
    end

    it 'returns turbo_stream error for invalid link' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/owned_projects",
           params: { project_id: 999 },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'creates a subordinate team via turbo_stream' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/subordinate_teams",
           params: { team: { name: 'SubTeam' } },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(TeamRecord.exists?(name: 'SubTeam')).to be(true)
    end

    it 'returns turbo_stream error for invalid subordinate team' do
      team = TeamRecord.create!(name: 'Platform Team')

      post "/teams/#{team.id}/subordinate_teams",
           params: { team: { name: '' } },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    end
end
