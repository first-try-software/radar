require_relative '../../lib/domain/initiatives/initiative'

class InitiativeRepository
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def find(id)
    record = InitiativeRecord.find_by(id: id)
    return nil unless record

    build_entity(record)
  end

  def save(initiative)
    record = InitiativeRecord.create!(
      name: initiative.name,
      description: initiative.description,
      point_of_contact: initiative.point_of_contact,
      archived: initiative.archived?,
      current_state: initiative.current_state.to_s
    )
    build_entity(record)
  end

  def update(id:, initiative:)
    record = InitiativeRecord.find_by(id: id)
    return unless record

    record.update!(
      name: initiative.name,
      description: initiative.description,
      point_of_contact: initiative.point_of_contact,
      archived: initiative.archived?,
      current_state: initiative.current_state.to_s
    )
  end

  def update_state(id:, state:)
    record = InitiativeRecord.find_by(id: id)
    return unless record

    record.update!(current_state: state.to_s)
  end

  def exists_with_name?(name)
    InitiativeRecord.exists?(name: name)
  end

  def link_related_project(initiative_id:, project:, order:)
    project_record = ProjectRecord.find_by!(name: project.name)
    initiative_record = InitiativeRecord.find_by!(id: initiative_id)

    InitiativesProjectRecord.create!(
      initiative: initiative_record,
      project: project_record,
      order: order
    )
  end

  def related_projects_for(initiative_id:)
    InitiativesProjectRecord
      .where(initiative_id: initiative_id)
      .order(:order)
      .includes(:project)
      .map do |rel|
        {
          initiative_id: rel.initiative_id.to_s,
          project: project_repository.find(rel.project_id),
          order: rel.order
        }
      end
  end

  def next_related_project_order(initiative_id:)
    max = InitiativesProjectRecord.where(initiative_id: initiative_id).maximum(:order)
    max ? max + 1 : 0
  end

  def related_project_exists?(initiative_id:, project_id:)
    InitiativesProjectRecord.exists?(initiative_id: initiative_id, project_id: project_id)
  end

  def unlink_related_project(initiative_id:, project_id:)
    InitiativesProjectRecord.where(initiative_id: initiative_id, project_id: project_id).destroy_all
  end

  def all_active_roots
    InitiativeRecord.where(archived: false).map { |record| build_entity(record) }
  end

  def all_archived
    InitiativeRecord.where(archived: true).map { |record| build_entity(record) }
  end

  private

  attr_reader :project_repository

  def build_entity(record)
    attributes = InitiativeAttributes.new(
      id: record.id.to_s,
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact,
      archived: record.archived,
      current_state: record.current_state.to_sym
    )
    loaders = InitiativeLoaders.new(
      related_projects: related_projects_loader_for(record)
    )
    Initiative.new(attributes: attributes, loaders: loaders)
  end

  def related_projects_loader_for(record)
    lambda do |_initiative|
      InitiativesProjectRecord
        .where(initiative_id: record.id)
        .order(:order)
        .includes(:project)
        .map { |rel| project_repository.find(rel.project_id) }
    end
  end
end
