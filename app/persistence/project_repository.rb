class ProjectRepository
  def initialize(health_update_repository:)
    @health_update_repository = health_update_repository
  end

  def find(id)
    record = ProjectRecord.find_by(id: id)
    return nil unless record

    build_entity(record)
  end

  def save(project)
    ProjectRecord.create!(
      name: project.name,
      description: project.description,
      point_of_contact: project.point_of_contact,
      archived: project.archived?,
      current_state: project.current_state
    )
  end

  def update(id:, project:)
    record = ProjectRecord.find_by(id: id)
    return unless record

    record.update!(
      name: project.name,
      description: project.description,
      point_of_contact: project.point_of_contact,
      archived: project.archived?,
      current_state: project.current_state
    )
  end

  def exists_with_name?(name)
    ProjectRecord.exists?(name: name)
  end

  def link_subordinate(parent_id:, child:, order:)
    child_record = ProjectRecord.find_by!(name: child.name)
    parent_record = ProjectRecord.find_by!(id: parent_id)

    ensure_single_parent!(child_record: child_record, parent_record: parent_record)

    ProjectsProjectRecord.create!(
      parent: parent_record,
      child: child_record,
      order: order
    )
  end

  def subordinate_relationships_for(parent_id:)
    ProjectsProjectRecord
      .where(parent_id: parent_id)
      .order(:order)
      .includes(:child)
      .map do |rel|
        {
          parent_id: rel.parent_id.to_s,
          child: build_entity(rel.child),
          order: rel.order
        }
      end
  end

  def next_subordinate_order(parent_id:)
    max = ProjectsProjectRecord.where(parent_id: parent_id).maximum(:order)
    max ? max + 1 : 0
  end

  private

  attr_reader :health_update_repository

  def build_entity(record)
    Project.new(
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact,
      archived: record.archived,
      current_state: record.current_state.to_sym,
      health_updates_loader: health_updates_loader_for(record),
      weekly_health_updates_loader: weekly_health_updates_loader_for(record),
      children_loader: children_loader_for(record),
      parent_loader: parent_loader_for(record)
    )
  end

  def health_updates_loader_for(record)
    lambda do |_project|
      health_update_repository.all_for_project(record.id)
    end
  end

  def weekly_health_updates_loader_for(record)
    lambda do |_project|
      health_update_repository.weekly_for_project(record.id)
    end
  end

  def children_loader_for(record)
    lambda do |_project|
      ProjectsProjectRecord
        .where(parent_id: record.id)
        .order(:order)
        .includes(:child)
        .map { |rel| build_entity(rel.child) }
    end
  end

  def parent_loader_for(record)
    lambda do |_project|
      rel = ProjectsProjectRecord.find_by(child_id: record.id)
      rel ? build_entity(rel.parent) : nil
    end
  end

  def ensure_single_parent!(child_record:, parent_record:)
    existing = ProjectsProjectRecord.find_by(child_id: child_record.id)
    return unless existing

    raise StandardError, 'child project already has a parent'
  end
end
