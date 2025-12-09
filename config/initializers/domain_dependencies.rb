require Rails.root.join('lib/domain/projects/create_project')
require Rails.root.join('lib/domain/projects/update_project')
require Rails.root.join('lib/domain/projects/set_project_state')
require Rails.root.join('lib/domain/projects/archive_project')
require Rails.root.join('lib/domain/projects/find_project')
require Rails.root.join('lib/domain/projects/create_subordinate_project')
require Rails.root.join('app/persistence/project_repository')
require Rails.root.join('app/services/project_actions_factory')

Rails.application.config.x.project_repository = ProjectRepository.new
Rails.application.config.x.project_actions = ProjectActionsFactory.new(
  project_repository: Rails.application.config.x.project_repository
)
