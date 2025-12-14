require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'domain/projects/project_loaders'

module ProjectBuilder
  def self.build(
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    current_state: :new,
    children_loader: nil,
    parent_loader: nil,
    health_updates_loader: nil,
    weekly_health_updates_loader: nil
  )
    attrs = ProjectAttributes.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived,
      current_state: current_state
    )
    loaders = ProjectLoaders.new(
      children: children_loader,
      parent: parent_loader,
      health_updates: health_updates_loader,
      weekly_health_updates: weekly_health_updates_loader
    )
    Project.new(attributes: attrs, loaders: loaders)
  end
end
