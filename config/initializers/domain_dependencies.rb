require Rails.root.join('app/persistence/project_repository')
require Rails.root.join('app/services/project_actions_factory')

Rails.application.config.x.project_repository = ProjectRepository.new
Rails.application.config.x.project_actions = ProjectActionsFactory.new(
  project_repository: Rails.application.config.x.project_repository
)
