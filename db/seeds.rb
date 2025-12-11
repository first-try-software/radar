require 'date'
require Rails.root.join('lib/domain/projects/health_update')

actions = Rails.application.config.x.project_actions
health_repository = Rails.application.config.x.health_update_repository

seed_projects = [
  { name: 'Atlas',   description: 'Platform tooling',      point_of_contact: 'Alex',  state: :in_progress, health: :on_track },
  { name: 'Beacon',  description: 'Customer insights',     point_of_contact: 'Bailey', state: :in_progress, health: :at_risk },
  { name: 'Crimson', description: 'Legacy decommission',   point_of_contact: 'Casey', state: :in_progress, health: :off_track },
  { name: 'Detour',  description: 'Risk mitigation',       point_of_contact: 'Dev',   state: :blocked,     health: :at_risk },
  { name: 'Hibernate', description: 'Paused initiative',   point_of_contact: 'Hayden', state: :on_hold,     health: nil },
  { name: 'Ship It', description: 'Release hardening',     point_of_contact: 'Sid',    state: :done,        health: nil },
  { name: 'Backlog', description: 'Upcoming work',         point_of_contact: 'Blair',  state: :todo,        health: nil },
  { name: 'Ideas',   description: 'Early exploration',     point_of_contact: 'Indy',   state: :new,         health: nil }
].freeze

seed_projects.each do |attrs|
  record = ProjectRecord.find_or_initialize_by(name: attrs[:name])
  record.description = attrs[:description]
  record.point_of_contact = attrs[:point_of_contact]
  record.archived = false
  record.current_state = attrs[:state].to_s if attrs[:state]
  record.save!

  next unless [:in_progress, :blocked].include?(attrs[:state]) && attrs[:health]

  already_has_health = HealthUpdateRecord.exists?(project_id: record.id, health: attrs[:health].to_s)
  next if already_has_health

  health_repository.save(
    HealthUpdate.new(
      project_id: record.id,
      date: Date.today,
      health: attrs[:health]
    )
  )
end
