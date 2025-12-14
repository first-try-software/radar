require 'rails_helper'

RSpec.describe InitiativesController, type: :request do
  let(:actions) { Rails.application.config.x.initiative_actions }
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'HTML endpoints' do
    it 'renders the index' do
      InitiativeRecord.create!(name: 'Launch 2025')

      get '/initiatives'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Launch 2025')
    end

    it 'renders a health indicator for initiatives on the index' do
      InitiativeRecord.create!(name: 'Launch 2025')

      get '/initiatives'

      expect(response.body).to include('project-health--not_available')
    end

    it 'renders the show page' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      get "/initiatives/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Launch 2025')
    end

    it 'renders a health indicator for the initiative on the show page' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      get "/initiatives/#{record.id}"

      expect(response.body).to include('project-health')
    end

    it 'links related projects to their show pages' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      get "/initiatives/#{initiative.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="/projects/#{project.id}">Feature A</a>))
    end

    it 'creates via HTML and redirects' do
      post '/initiatives', params: { initiative: { name: 'Launch 2025' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Launch 2025')
    end

    it 'renders validation errors on HTML create' do
      post '/initiatives', params: { initiative: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
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

    it 'creates related project via HTML and redirects' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects", params: { project: { name: 'Feature A' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Feature A')
    end

    it 'renders validation errors on HTML related project create' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'returns 404 for missing initiative on HTML related project create' do
      post '/initiatives/999/related_projects', params: { project: { name: 'Feature A' } }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 on HTML related project create when initiative deleted mid-request' do
      initiative = InitiativeRecord.create!(name: 'Ephemeral')
      params = { project: { name: '' } }

      call_count = 0
      allow(InitiativeRecord).to receive(:find_by).and_wrap_original do |method, *args|
        call_count += 1
        call_count <= 1 ? method.call(*args) : nil
      end

      post "/initiatives/#{initiative.id}/related_projects", params: params

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /initiatives.json' do
    it 'lists initiatives as JSON' do
      InitiativeRecord.create!(name: 'Launch 2025')

      get '/initiatives.json'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |i| i['name'] }).to include('Launch 2025')
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
    it 'creates a related project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects", params: { project: { name: 'Feature A' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Feature A')
    end

    it 'returns 404 when initiative not found' do
      post '/initiatives/999/related_projects', params: { project: { name: 'Feature A' } }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns errors for invalid project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')

      post "/initiatives/#{initiative.id}/related_projects", params: { project: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end
end
