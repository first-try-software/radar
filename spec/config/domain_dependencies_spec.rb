require 'rails_helper'

RSpec.describe 'domain dependency wiring' do
  let(:actions) { Rails.application.config.x.project_actions }
  let(:repository) { Rails.application.config.x.project_repository }
  let(:health_repository) { Rails.application.config.x.health_update_repository }

  it 'builds project actions with the shared project repository' do
    expect(actions).to be_a(ProjectActionsFactory)
    expect(actions.create_project).to be_a(CreateProject)
    expect(actions.create_project.instance_variable_get(:@project_repository)).to equal(repository)

    expect(actions.update_project).to be_a(UpdateProject)
    expect(actions.set_project_state).to be_a(SetProjectState)
    expect(actions.archive_project).to be_a(ArchiveProject)
    expect(actions.find_project).to be_a(FindProject)
    expect(actions.create_subordinate_project).to be_a(CreateSubordinateProject)
    expect(actions.create_project_health_update).to be_a(CreateProjectHealthUpdate)
    expect(actions.create_project_health_update.instance_variable_get(:@health_update_repository)).to equal(health_repository)
  end
end
