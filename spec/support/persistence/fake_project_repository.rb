class FakeProjectRepository
  def initialize(projects: {})
    @records = projects
    @relationships = []
  end

  def find(id)
    records[id]
  end

  def update(id:, project:)
    records[id] = project
  end

  def update_by_name(name:, project:)
    key = records.keys.find { |k| records[k].name == name }
    records[key] = project if key
  end

  def save(project)
    records[project.name] = project
  end

  def exists_with_name?(name)
    records.values.any? { |proj| proj.name == name }
  end

  def link_subordinate(parent_id:, child: nil, child_id: nil, order:)
    actual_child = child || records[child_id]
    actual_child_id = child_id || child_key(actual_child)
    ensure_single_parent!(child_id: actual_child_id)
    relationships << { parent_id:, child: actual_child, child_id: actual_child_id, order: }
  end

  def subordinate_relationships_for(parent_id:)
    relationships.select { |rel| rel[:parent_id] == parent_id }
  end

  def next_subordinate_order(parent_id:)
    max = subordinate_relationships_for(parent_id: parent_id).map { |rel| rel[:order] }.max
    max ? max + 1 : 0
  end

  def subordinate_exists?(parent_id:, child_id:)
    relationships.any? { |rel| rel[:parent_id] == parent_id && rel[:child_id] == child_id }
  end

  def unlink_subordinate(parent_id:, child_id:)
    relationships.reject! { |rel| rel[:parent_id] == parent_id && rel[:child_id] == child_id }
  end

  def has_parent?(child_id:)
    relationships.any? { |rel| rel[:child_id] == child_id }
  end

  def all_active_roots
    records.values.reject do |project|
      project.archived? || has_parent?(child_id: child_key(project))
    end
  end

  def orphan_projects
    # In the fake repo, we just return root projects without parents
    # (team ownership is not tracked in the fake)
    all_active_roots
  end

  def link_child(parent_id:, child:, order:)
    link_subordinate(parent_id: parent_id, child: child, order: order)
  end

  private

  attr_reader :records, :relationships

  def child_key(child)
    child.respond_to?(:name) ? child.name : child.object_id
  end

  def ensure_single_parent!(child_id:)
    existing = relationships.find { |rel| rel[:child_id] == child_id }
    return unless existing

    raise StandardError, 'child project already has a parent'
  end
end
