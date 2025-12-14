Rails.application.config.to_prepare do
  require_dependency Rails.root.join('lib/domain/projects/create_project')
  require_dependency Rails.root.join('lib/domain/projects/update_project')
  require_dependency Rails.root.join('lib/domain/projects/set_project_state')
  require_dependency Rails.root.join('lib/domain/projects/archive_project')
  require_dependency Rails.root.join('lib/domain/projects/find_project')
  require_dependency Rails.root.join('lib/domain/projects/create_subordinate_project')
  require_dependency Rails.root.join('lib/domain/projects/record_project_health_update')
  require_dependency Rails.root.join('lib/domain/initiatives/create_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/find_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/update_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/archive_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/create_related_project')
  require_dependency Rails.root.join('app/persistence/project_repository')
  require_dependency Rails.root.join('app/persistence/health_update_repository')
  require_dependency Rails.root.join('app/persistence/initiative_repository')
  require_dependency Rails.root.join('app/services/project_actions_factory')
  require_dependency Rails.root.join('app/services/initiative_actions_factory')

  Rails.application.config.x.health_update_repository = HealthUpdateRepository.new
  Rails.application.config.x.project_repository = ProjectRepository.new(
    health_update_repository: Rails.application.config.x.health_update_repository
  )
  Rails.application.config.x.project_actions = ProjectActionsFactory.new(
    project_repository: Rails.application.config.x.project_repository,
    health_update_repository: Rails.application.config.x.health_update_repository
  )
  Rails.application.config.x.initiative_repository = InitiativeRepository.new(
    project_repository: Rails.application.config.x.project_repository
  )
  Rails.application.config.x.initiative_actions = InitiativeActionsFactory.new(
    initiative_repository: Rails.application.config.x.initiative_repository,
    project_repository: Rails.application.config.x.project_repository
  )
end
