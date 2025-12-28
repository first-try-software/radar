require 'rails_helper'

RSpec.describe ProjectsController, type: :request do
  let(:actions) { Rails.application.config.x.project_actions }
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }
  let(:turbo_stream_headers) { { 'ACCEPT' => 'text/vnd.turbo-stream.html' } }

  describe 'HTML endpoints' do
    it 'renders the show page for a leaf project' do
      record = ProjectRecord.create!(name: 'Alpha')
      HealthUpdateRecord.create!(project: record, date: Date.current, health: 'on_track')

      get "/projects/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha')
    end

    it 'renders the show page for a parent project with children' do
      parent = ProjectRecord.create!(name: 'Parent Project')
      child = ProjectRecord.create!(name: 'Child Project')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)
      HealthUpdateRecord.create!(project: child, date: Date.current, health: 'on_track')

      get "/projects/#{parent.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Parent Project')
      expect(response.body).to include('Projects')
    end

    it 'creates health update via HTML and redirects' do
      record = ProjectRecord.create!(name: 'Solo', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'on_track', description: 'All good' } }

      post "/projects/#{record.id}/health_updates", params: params

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(project_path(record))
    end

    it 'renders validation errors on HTML health update with invalid health' do
      record = ProjectRecord.create!(name: 'Solo', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'bogus' } }

      post "/projects/#{record.id}/health_updates", params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('invalid health')
    end

    it 'renders validation errors on HTML health update with invalid date' do
      record = ProjectRecord.create!(name: 'Solo', current_state: 'in_progress')
      params = { health_update: { date: 'not-a-date', health: 'on_track' } }

      post "/projects/#{record.id}/health_updates", params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('date is required')
    end

    it 'renders validation errors on HTML health update with nil date' do
      record = ProjectRecord.create!(name: 'Solo', current_state: 'in_progress')
      params = { health_update: { date: nil, health: 'on_track' } }

      post "/projects/#{record.id}/health_updates", params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('date is required')
    end

    it 'returns 404 on HTML health update for missing project' do
      params = { health_update: { date: Date.current, health: 'on_track' } }

      post '/projects/999/health_updates', params: params

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 on HTML health update when project deleted mid-request' do
      record = ProjectRecord.create!(name: 'Ephemeral', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'bogus' } }

      # First call finds project (in action), subsequent calls return nil (simulating deletion)
      call_count = 0
      allow(ProjectRecord).to receive(:find_by).and_wrap_original do |method, *args|
        call_count += 1
        call_count <= 1 ? method.call(*args) : nil
      end

      post "/projects/#{record.id}/health_updates", params: params

      expect(response).to have_http_status(:not_found)
    end

    it 'creates via HTML and redirects' do
      post '/projects', params: { project: { name: 'Beta' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Beta')
    end

    it 'redirects with error on HTML create failure' do
      post '/projects', params: { project: { name: '' } }

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(root_path)
    end

    it 'updates via HTML and redirects' do
      record = ProjectRecord.create!(name: 'Epsilon')

      patch "/projects/#{record.id}", params: { project: { name: 'Zeta' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Zeta')
    end

    it 'renders errors on HTML update failure' do
      record = ProjectRecord.create!(name: 'BadName')

      patch "/projects/#{record.id}", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
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
      expect(ProjectRecord.exists?(name: 'Kappa')).to be(true)
    end

    it 'renders validation errors on HTML subordinate create' do
      parent = ProjectRecord.create!(name: 'Lambda')

      post "/projects/#{parent.id}/subordinates", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'returns 404 on HTML subordinate create when parent deleted mid-request' do
      parent = ProjectRecord.create!(name: 'Ephemeral')

      # First call finds parent (in action), subsequent calls return nil (simulating deletion)
      call_count = 0
      allow(ProjectRecord).to receive(:find_by).and_wrap_original do |method, *args|
        call_count += 1
        call_count <= 1 ? method.call(*args) : nil
      end

      post "/projects/#{parent.id}/subordinates", params: { project: { name: '' } }

      expect(response).to have_http_status(:not_found)
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

    it 'returns 404 for HTML state change on missing project' do
      patch '/projects/999/state', params: { state: 'done' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for HTML state change when project deleted mid-request' do
      record = ProjectRecord.create!(name: 'Ephemeral', current_state: 'todo')

      # First call finds project (in action), subsequent calls return nil (simulating deletion)
      call_count = 0
      allow(ProjectRecord).to receive(:find_by).and_wrap_original do |method, *args|
        call_count += 1
        call_count <= 1 ? method.call(*args) : nil
      end

      patch "/projects/#{record.id}/state", params: { state: 'bogus' }

      expect(response).to have_http_status(:not_found)
    end

    it 'renders validation errors on HTML update' do
      record = ProjectRecord.create!(name: 'Delta')

      patch "/projects/#{record.id}", params: { project: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('name must be present')
    end

    it 'archives a project via HTML update' do
      record = ProjectRecord.create!(name: 'Archivable', archived: false)

      patch "/projects/#{record.id}", params: { project: { name: 'Archivable', archived: '1' } }

      expect(response).to redirect_to(project_path(record))
      record.reload
      expect(record.archived).to be(true)
    end

    it 'unarchives a project via HTML update' do
      record = ProjectRecord.create!(name: 'Unarchivable', archived: true)

      patch "/projects/#{record.id}", params: { project: { name: 'Unarchivable', archived: '0' } }

      expect(response).to redirect_to(project_path(record))
      record.reload
      expect(record.archived).to be(false)
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
    it 'shows a project with no health updates (health not in allowed list)' do
      record = ProjectRecord.create!(name: 'NoHealth')

      get "/projects/#{record.id}"

      expect(response).to have_http_status(:ok)
    end

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

    it 'archives a project via JSON update with boolean true' do
      record = ProjectRecord.create!(name: 'ToArchive', archived: false)

      patch "/projects/#{record.id}", params: { project: { name: 'ToArchive', archived: true } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['archived']).to eq(true)
      record.reload
      expect(record.archived).to be(true)
    end

    it 'archives a project via update with string true' do
      record = ProjectRecord.create!(name: 'StringArchive', archived: false)

      patch "/projects/#{record.id}", params: { project: { name: 'StringArchive', archived: 'true' } }, headers: json_headers

      expect(response).to have_http_status(:ok)
      record.reload
      expect(record.archived).to be(true)
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

  describe 'PATCH /projects/:id/unarchive' do
    it 'unarchives a project' do
      record = ProjectRecord.create!(name: 'Alpha', archived: true)

      patch "/projects/#{record.id}/unarchive", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['archived']).to eq(false)
    end

    it 'returns 404 when project is missing' do
      patch "/projects/999/unarchive", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'unarchives via HTML and redirects' do
      record = ProjectRecord.create!(name: 'Beta', archived: true)

      patch "/projects/#{record.id}/unarchive"

      expect(response).to have_http_status(:found)
      record.reload
      expect(record.archived).to be(false)
    end

    it 'returns 404 for missing project in HTML unarchive' do
      patch '/projects/999/unarchive'

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

  describe 'DELETE /projects/:id/subordinates/:child_id' do
    it 'unlinks a child project from a parent' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)

      delete "/projects/#{parent.id}/subordinates/#{child.id}", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(ProjectsProjectRecord.where(parent: parent, child: child)).to be_empty
    end

    it 'unlinks via HTML and redirects' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)

      delete "/projects/#{parent.id}/subordinates/#{child.id}"

      expect(response).to have_http_status(:found)
      expect(ProjectsProjectRecord.where(parent: parent, child: child)).to be_empty
    end

    it 'returns 404 when parent not found' do
      child = ProjectRecord.create!(name: 'Child')

      delete "/projects/999/subordinates/#{child.id}", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when child not linked' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')

      delete "/projects/#{parent.id}/subordinates/#{child.id}", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for HTML when child not linked' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')

      delete "/projects/#{parent.id}/subordinates/#{child.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /projects/:id/subordinates/link' do
    it 'links an existing project as a child' do
      parent = ProjectRecord.create!(name: 'Parent')
      orphan = ProjectRecord.create!(name: 'Orphan')

      post "/projects/#{parent.id}/subordinates/link", params: { child_id: orphan.id }, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(ProjectsProjectRecord.where(parent: parent, child: orphan)).to exist
    end

    it 'links via HTML and redirects' do
      parent = ProjectRecord.create!(name: 'Parent')
      orphan = ProjectRecord.create!(name: 'Orphan')

      post "/projects/#{parent.id}/subordinates/link", params: { child_id: orphan.id }

      expect(response).to have_http_status(:found)
      expect(ProjectsProjectRecord.where(parent: parent, child: orphan)).to exist
    end

    it 'returns 404 when parent not found' do
      orphan = ProjectRecord.create!(name: 'Orphan')

      post "/projects/999/subordinates/link", params: { child_id: orphan.id }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when child not found' do
      parent = ProjectRecord.create!(name: 'Parent')

      post "/projects/#{parent.id}/subordinates/link", params: { child_id: 999 }, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error when child already has a parent' do
      parent1 = ProjectRecord.create!(name: 'Parent1')
      parent2 = ProjectRecord.create!(name: 'Parent2')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent1, child: child, order: 0)

      post "/projects/#{parent2.id}/subordinates/link", params: { child_id: child.id }, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders error on HTML when child already has a parent' do
      parent1 = ProjectRecord.create!(name: 'Parent1')
      parent2 = ProjectRecord.create!(name: 'Parent2')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent1, child: child, order: 0)

      post "/projects/#{parent2.id}/subordinates/link", params: { child_id: child.id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('already has a parent')
    end

    it 'returns 404 for HTML when parent not found' do
      orphan = ProjectRecord.create!(name: 'Orphan')

      post "/projects/999/subordinates/link", params: { child_id: orphan.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'parse_date private method' do
    it 'returns the value unchanged when it is already a Date' do
      controller = ProjectsController.new
      date = Date.new(2025, 6, 15)

      result = controller.send(:parse_date, date)

      expect(result).to eq(date)
    end

    it 'returns nil when value is nil' do
      controller = ProjectsController.new

      result = controller.send(:parse_date, nil)

      expect(result).to be_nil
    end

    it 'returns nil when value is empty string' do
      controller = ProjectsController.new

      result = controller.send(:parse_date, '')

      expect(result).to be_nil
    end
  end

  describe 'POST /projects/:id/health_updates' do
    it 'creates a health update and returns the new health as JSON' do
      record = ProjectRecord.create!(name: 'Alpha', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'on_track' } }

      post "/projects/#{record.id}/health_updates", params: params, headers: json_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['health']).to eq('on_track')
    end

    it 'returns errors for invalid health update as JSON' do
      record = ProjectRecord.create!(name: 'Alpha', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'bogus' } }

      post "/projects/#{record.id}/health_updates", params: params, headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('invalid health')
    end

    it 'returns 404 for missing project as JSON' do
      params = { health_update: { date: Date.current, health: 'on_track' } }

      post '/projects/999/health_updates', params: params, headers: json_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'creates a health update via turbo_stream and returns stream response' do
      record = ProjectRecord.create!(name: 'Turbo', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'on_track', description: 'All good' } }

      post "/projects/#{record.id}/health_updates", params: params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'returns turbo_stream error for invalid health update' do
      record = ProjectRecord.create!(name: 'Turbo', current_state: 'in_progress')
      params = { health_update: { date: Date.current, health: 'bogus' } }

      post "/projects/#{record.id}/health_updates", params: params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end

  describe 'POST /projects/:id/subordinates turbo_stream' do
    it 'creates a subordinate project via turbo_stream' do
      parent = ProjectRecord.create!(name: 'TurboParent')

      post "/projects/#{parent.id}/subordinates", params: { project: { name: 'TurboChild' } }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(ProjectRecord.exists?(name: 'TurboChild')).to be(true)
    end

    it 'returns turbo_stream error for invalid subordinate' do
      parent = ProjectRecord.create!(name: 'TurboParent')

      post "/projects/#{parent.id}/subordinates", params: { project: { name: '' } }, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end
end
