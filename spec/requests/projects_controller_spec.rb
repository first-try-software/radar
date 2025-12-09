require 'rails_helper'

RSpec.describe ProjectsController, type: :request do
  let(:actions) { Rails.application.config.x.project_actions }
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'HTML endpoints' do
    it 'renders the index' do
      ProjectRecord.create!(name: 'Alpha')

      get '/projects'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha')
    end

    it 'only lists projects without a parent' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)

      get '/projects'

      expect(response.body).to include('Parent')
      expect(response.body).not_to include('Child')
    end

    it 'renders the new project form inline at the bottom of root projects' do
      ProjectRecord.create!(name: 'Rooty')

      get '/projects'

      expect(response.body).to include('Root Projects')
      expect(response.body).not_to include('All Projects')
      expect(response.body).to include('child-actions')
      expect(response.body).to include('New root project name')
      expect(response.body).to include('Add')

      root_index = response.body.index('Rooty')
      form_index = response.body.index('New root project name')
      expect(root_index).to be < form_index
    end

    it 'humanizes state labels for root projects' do
      ProjectRecord.create!(name: 'Rooty', current_state: 'in_progress')

      get '/projects'

      expect(response.body).to include('In Progress')
      expect(response.body).not_to include('in_progress')
    end

    it 'renders the show page' do
      record = ProjectRecord.create!(name: 'Alpha')

      get "/projects/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha')
    end

    it 'links children to their show pages' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 1)

      get "/projects/#{parent.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="/projects/#{child.id}">Child</a>))
    end

    it 'humanizes child states on the show page' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child', current_state: 'in_progress')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)

      get "/projects/#{parent.id}"

      expect(response.body).to include('In Progress')
      expect(response.body).not_to include('in_progress')
    end

    it 'renders child project cards like the index, with heading and description' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(
        name: 'Child',
        description: 'Child description',
        current_state: 'blocked',
        archived: true
      )
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)

      get "/projects/#{parent.id}"

      expect(response.body).to include(%(class="section-title children-title">Projects))
      expect(response.body).to include('Child description')
      expect(response.body).to include('Blocked')
      expect(response.body).to include('archived')
    end

    it 'creates via HTML and redirects' do
      post '/projects', params: { project: { name: 'Beta' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Beta')
    end

    it 'renders validation errors on HTML create' do
      post '/projects', params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'updates via HTML and redirects' do
      record = ProjectRecord.create!(name: 'Epsilon')

      patch "/projects/#{record.id}", params: { project: { name: 'Zeta' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Zeta')
    end

    it 'updates state via HTML and redirects' do
      record = ProjectRecord.create!(name: 'Eta', current_state: 'todo')

      patch "/projects/#{record.id}/state", params: { state: 'in_progress' }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('In Progress')
    end

    it 'archives via HTML and redirects' do
      record = ProjectRecord.create!(name: 'Theta')

      patch "/projects/#{record.id}/archive"

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('archived')
    end

    it 'creates subordinate via HTML and redirects' do
      parent = ProjectRecord.create!(name: 'Iota')

      post "/projects/#{parent.id}/subordinates", params: { project: { name: 'Kappa' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Kappa')
    end

    it 'renders validation errors on HTML subordinate create' do
      parent = ProjectRecord.create!(name: 'Lambda')

      post "/projects/#{parent.id}/subordinates", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'returns 404 for missing parent on HTML subordinate create' do
      post "/projects/999/subordinates", params: { project: { name: 'MissingParent' } }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for missing project in HTML archive' do
      patch '/projects/999/archive'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for missing project in HTML show' do
      get '/projects/999'

      expect(response).to have_http_status(:not_found)
    end

    it 'renders validation errors on HTML state change' do
      record = ProjectRecord.create!(name: 'Gamma')

      patch "/projects/#{record.id}/state", params: { state: 'bogus' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('invalid state')
    end

    it 'renders validation errors on HTML update' do
      record = ProjectRecord.create!(name: 'Delta')

      patch "/projects/#{record.id}", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end
  end

  describe 'GET /projects.json' do
    it 'lists projects as JSON' do
      ProjectRecord.create!(name: 'ListMe')

      get '/projects.json'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |p| p['name'] }).to include('ListMe')
    end
  end

  describe 'POST /projects' do
    it 'creates a project' do
      post '/projects', params: { project: { name: 'Alpha', description: 'desc', point_of_contact: 'me' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Alpha')
    end

    it 'returns errors for invalid project' do
      post '/projects', params: { project: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end

  describe 'GET /projects/:id' do
    it 'shows a project' do
      record = ProjectRecord.create!(name: 'Alpha')

      get "/projects/#{record.id}", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Alpha')
    end

    it 'returns 404 when not found' do
      get '/projects/999', headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /projects/:id' do
    it 'updates a project' do
      record = ProjectRecord.create!(name: 'Alpha')

      patch "/projects/#{record.id}", params: { project: { name: 'Beta' } }, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Beta')
    end

    it 'returns errors for invalid update' do
      record = ProjectRecord.create!(name: 'Alpha')

      patch "/projects/#{record.id}", params: { project: { name: '' } }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('name must be present')
    end
  end

  describe 'PATCH /projects/:id/state' do
    it 'sets project state' do
      record = ProjectRecord.create!(name: 'Alpha', current_state: 'todo')

      patch "/projects/#{record.id}/state", params: { state: 'in_progress' }, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['current_state']).to eq('in_progress')
    end

    it 'returns 422 for invalid state' do
      record = ProjectRecord.create!(name: 'Alpha')

      patch "/projects/#{record.id}/state", params: { state: 'bogus' }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('invalid state')
    end
  end

  describe 'PATCH /projects/:id/archive' do
    it 'archives a project' do
      record = ProjectRecord.create!(name: 'Alpha')

      patch "/projects/#{record.id}/archive", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['archived']).to eq(true)
    end

    it 'returns 404 when project is missing' do
      patch "/projects/999/archive", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /projects/:id/subordinates' do
    it 'creates a subordinate project' do
      parent = ProjectRecord.create!(name: 'Parent')

      post "/projects/#{parent.id}/subordinates", params: { project: { name: 'Child' } }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('Child')
    end

    it 'returns 404 when parent not found' do
      post "/projects/999/subordinates", params: { project: { name: 'Child' } }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
