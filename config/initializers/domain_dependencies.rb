Rails.application.config.to_prepare do
  require_dependency Rails.root.join('lib/domain/projects/create_project')
  require_dependency Rails.root.join('lib/domain/projects/update_project')
  require_dependency Rails.root.join('lib/domain/projects/set_project_state')
  require_dependency Rails.root.join('lib/domain/projects/archive_project')
  require_dependency Rails.root.join('lib/domain/projects/unarchive_project')
  require_dependency Rails.root.join('lib/domain/projects/unlink_subordinate_project')
  require_dependency Rails.root.join('lib/domain/projects/link_subordinate_project')
  require_dependency Rails.root.join('lib/domain/projects/link_subordinate_project')
  require_dependency Rails.root.join('lib/domain/projects/find_project')
  require_dependency Rails.root.join('lib/domain/projects/create_subordinate_project')
  require_dependency Rails.root.join('lib/domain/projects/record_project_health_update')
  require_dependency Rails.root.join('lib/domain/projects/project_trend_service')
  require_dependency Rails.root.join('lib/domain/initiatives/create_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/find_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/update_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/archive_initiative')
  require_dependency Rails.root.join('lib/domain/initiatives/link_related_project')
  require_dependency Rails.root.join('lib/domain/initiatives/unlink_related_project')
  require_dependency Rails.root.join('lib/domain/initiatives/set_initiative_state')
  require_dependency Rails.root.join('lib/domain/initiatives/initiative_dashboard')
  require_dependency Rails.root.join('lib/domain/initiatives/initiative_trend_service')
  require_dependency Rails.root.join('lib/domain/teams/create_team')
  require_dependency Rails.root.join('lib/domain/teams/find_team')
  require_dependency Rails.root.join('lib/domain/teams/update_team')
  require_dependency Rails.root.join('lib/domain/teams/archive_team')
  require_dependency Rails.root.join('lib/domain/teams/create_subordinate_team')
  require_dependency Rails.root.join('lib/domain/teams/create_owned_project')
  require_dependency Rails.root.join('lib/domain/teams/link_owned_project')
  require_dependency Rails.root.join('lib/domain/teams/team_trend_service')
  require_dependency Rails.root.join('lib/domain/teams/team_dashboard')
  require_dependency Rails.root.join('lib/domain/dashboard/dashboard')
  require_dependency Rails.root.join('lib/domain/dashboard/system_trend_service')
  require_dependency Rails.root.join('app/persistence/project_repository')
  require_dependency Rails.root.join('app/persistence/health_update_repository')
  require_dependency Rails.root.join('app/persistence/initiative_repository')
  require_dependency Rails.root.join('app/persistence/team_repository')
  require_dependency Rails.root.join('app/services/project_actions_factory')
  require_dependency Rails.root.join('app/services/initiative_actions_factory')
  require_dependency Rails.root.join('app/services/team_actions_factory')

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
  Rails.application.config.x.team_repository = TeamRepository.new(
    project_repository: Rails.application.config.x.project_repository
  )
  Rails.application.config.x.team_actions = TeamActionsFactory.new(
    team_repository: Rails.application.config.x.team_repository,
    project_repository: Rails.application.config.x.project_repository
  )
  Rails.application.config.x.dashboard = Dashboard.new(
    project_repository: Rails.application.config.x.project_repository,
    health_update_repository: Rails.application.config.x.health_update_repository,
    initiative_repository: Rails.application.config.x.initiative_repository,
    team_repository: Rails.application.config.x.team_repository
  )
end
