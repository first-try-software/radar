require 'rails_helper'

RSpec.describe InitiativesController, type: :request do
  let(:actions) { Rails.application.config.x.initiative_actions }
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'HTML endpoints' do
    it 'renders the show page' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      get "/initiatives/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Launch 2025')
    end

    it 'renders a health indicator for the initiative on the show page' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      get "/initiatives/#{record.id}"

      expect(response.body).to include('metric-widget__dot')
    end

    it 'renders metrics widgets on the show page' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      on_track = ProjectRecord.create!(name: 'On Track', current_state: 'in_progress')
      at_risk = ProjectRecord.create!(name: 'At Risk', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: on_track, date: Date.current, health: 'on_track')
      HealthUpdateRecord.create!(project: at_risk, date: Date.current, health: 'at_risk')
      InitiativesProjectRecord.create!(initiative: initiative, project: on_track, order: 0)
      InitiativesProjectRecord.create!(initiative: initiative, project: at_risk, order: 1)

      get "/initiatives/#{initiative.id}"

      expect(response.body).to include('metrics-row-v2')
      expect(response.body).to include('metric-widget')
    end

    it 'renders unhealthy tab on the show page' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      off_track = ProjectRecord.create!(name: 'Off Track Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: off_track, date: Date.current, health: 'off_track')
      InitiativesProjectRecord.create!(initiative: initiative, project: off_track, order: 0)

      get "/initiatives/#{initiative.id}"

      expect(response.body).to include('Unhealthy')
      expect(response.body).to include('Off Track Project')
    end

    it 'renders stale tab on the show page' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      stale_project = ProjectRecord.create!(name: 'Stale Project', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: stale_project, date: Date.current - 20, health: 'on_track')
      InitiativesProjectRecord.create!(initiative: initiative, project: stale_project, order: 0)

      get "/initiatives/#{initiative.id}"

      expect(response.body).to include('Stale')
      expect(response.body).to include('Stale Project')
    end

    it 'renders global search on the show page' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      get "/initiatives/#{initiative.id}"

      expect(response.body).to include('Find or create what you are looking for...')
    end

    it 'links projects in attention sections to their show pages with initiative ref' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A', current_state: 'in_progress')
      # Create a never-updated project so it shows in the Needs Update section
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      get "/initiatives/#{initiative.id}"

      expect(response).to have_http_status(:ok)
      # Project should appear in Needs Update section with initiative ref
      expect(response.body).to include(%(href="/projects/#{project.id}?ref=initiative%3A#{initiative.id}"))
      expect(response.body).to include('Feature A')
    end

    it 'creates via HTML and redirects' do
      post '/initiatives', params: { initiative: { name: 'Launch 2025' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Launch 2025')
    end

    it 'redirects with error on HTML create failure' do
      post '/initiatives', params: { initiative: { name: '' } }

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(root_path)
    end

    it 'updates via HTML and redirects' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}", params: { initiative: { name: 'Launch 2026' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Launch 2026')
    end

    it 'renders validation errors on HTML update' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}", params: { initiative: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'archives via HTML and redirects' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}/archive"

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('archived')
    end

    it 'returns 404 for missing initiative in HTML archive' do
      patch '/initiatives/999/archive'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for missing initiative in HTML show' do
      get '/initiatives/999'

      expect(response).to have_http_status(:not_found)
    end

    it 'links existing project via HTML and redirects' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')

      post "/initiatives/#{initiative.id}/related_projects", params: { project_id: project.id }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Project linked')
    end

    it 'returns 404 for missing initiative on HTML link project' do
      project = ProjectRecord.create!(name: 'Feature A')

      post '/initiatives/999/related_projects', params: { project_id: project.id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for missing project on HTML link project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects", params: { project_id: 999 }

      expect(response).to have_http_status(:not_found)
    end

    it 'creates and links a new project via HTML add_related_project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects/add", params: { project: { name: 'New Feature' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Project added and linked')
      expect(ProjectRecord.find_by(name: 'New Feature')).to be_present
    end

    it 'returns error when add_related_project fails to create project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects/add", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'creates and links project via JSON add_related_project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects/add", params: { project: { name: 'New Feature' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('New Feature')
    end

    it 'returns error via JSON when add_related_project fails to create project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects/add", params: { project: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end

    it 'returns error via HTML when add_related_project link fails' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      # Stub any instance of LinkRelatedProject to fail
      allow_any_instance_of(LinkRelatedProject).to receive(:perform).and_return(
        Result.failure(errors: ['link failed'])
      )

      post "/initiatives/#{initiative.id}/related_projects/add", params: { project: { name: 'New Project' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('link failed')
    end

    it 'handles missing domain initiative gracefully when add_related_project link fails' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      # Stub link to fail AND find_initiative to fail (covers the else branch of find_domain_initiative)
      allow_any_instance_of(LinkRelatedProject).to receive(:perform).and_return(
        Result.failure(errors: ['link failed'])
      )
      allow_any_instance_of(FindInitiative).to receive(:perform).and_return(
        Result.failure(errors: ['not found'])
      )

      post "/initiatives/#{initiative.id}/related_projects/add", params: { project: { name: 'Another Project' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST /initiatives' do
    it 'creates an initiative' do
      post '/initiatives', params: { initiative: { name: 'Launch 2025', description: 'desc', point_of_contact: 'me' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Launch 2025')
    end

    it 'returns errors for invalid initiative' do
      post '/initiatives', params: { initiative: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end

  describe 'GET /initiatives/:id' do
    it 'shows an initiative' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      get "/initiatives/#{record.id}", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Launch 2025')
    end

    it 'returns 404 when not found' do
      get '/initiatives/999999', headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /initiatives/:id' do
    it 'updates an initiative' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}", params: { initiative: { name: 'Launch 2026' } }, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Launch 2026')
    end

    it 'returns errors for invalid update' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}", params: { initiative: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end

  describe 'PATCH /initiatives/:id/state' do
    it 'updates initiative state' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}/state", params: { state: 'in_progress' }, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['current_state']).to eq('in_progress')
    end

    it 'updates state via HTML and redirects' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}/state", params: { state: 'in_progress' }

      expect(response).to redirect_to(initiative_path(record))
      record.reload
      expect(record.current_state).to eq('in_progress')
    end

    it 'cascades state to related projects when cascade is true' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A', current_state: 'in_progress')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      patch "/initiatives/#{initiative.id}/state", params: { state: 'done', cascade: 'true' }, headers: json_headers

      expect(response).to have_http_status(:ok)
      project.reload
      expect(project.current_state).to eq('done')
    end

    it 'does not cascade when cascade is not specified' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A', current_state: 'in_progress')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      patch "/initiatives/#{initiative.id}/state", params: { state: 'done' }, headers: json_headers

      expect(response).to have_http_status(:ok)
      project.reload
      expect(project.current_state).to eq('in_progress')
    end

    it 'returns 404 when initiative is missing' do
      patch '/initiatives/999/state', params: { state: 'in_progress' }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error for invalid state' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}/state", params: { state: 'invalid' }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 via HTML when initiative not found' do
      patch '/initiatives/999/state', params: { state: 'in_progress' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /initiatives/:id/archive' do
    it 'archives an initiative' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      patch "/initiatives/#{record.id}/archive", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['archived']).to eq(true)
    end

    it 'returns 404 when initiative is missing' do
      patch '/initiatives/999/archive', headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /initiatives/:id/related_projects' do
    it 'links an existing project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')

      post "/initiatives/#{initiative.id}/related_projects", params: { project_id: project.id }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Feature A')
    end

    it 'returns 404 when initiative not found' do
      project = ProjectRecord.create!(name: 'Feature A')

      post '/initiatives/999/related_projects', params: { project_id: project.id }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when project not found' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects", params: { project_id: 999 }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'allows linking a project to multiple initiatives' do
      initiative1 = InitiativeRecord.create!(name: 'Launch 2025')
      initiative2 = InitiativeRecord.create!(name: 'Launch 2026')
      project = ProjectRecord.create!(name: 'Shared Project')

      post "/initiatives/#{initiative1.id}/related_projects", params: { project_id: project.id }, headers: json_headers
      expect(response).to have_http_status(:created)

      post "/initiatives/#{initiative2.id}/related_projects", params: { project_id: project.id }, headers: json_headers
      expect(response).to have_http_status(:created)

      expect(InitiativesProjectRecord.where(project_id: project.id).count).to eq(2)
    end
  end

  describe 'DELETE /initiatives/:id/related_projects/:project_id' do
    it 'unlinks a project from an initiative' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      delete "/initiatives/#{initiative.id}/related_projects/#{project.id}", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(InitiativesProjectRecord.where(initiative: initiative, project: project)).to be_empty
    end

    it 'unlinks via HTML and redirects' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      delete "/initiatives/#{initiative.id}/related_projects/#{project.id}"

      expect(response).to have_http_status(:found)
      expect(InitiativesProjectRecord.where(initiative: initiative, project: project)).to be_empty
    end

    it 'returns 404 when initiative not found' do
      project = ProjectRecord.create!(name: 'Feature A')

      delete "/initiatives/999/related_projects/#{project.id}", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when project not linked' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')

      delete "/initiatives/#{initiative.id}/related_projects/#{project.id}", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for HTML when project not linked' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')

      delete "/initiatives/#{initiative.id}/related_projects/#{project.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
