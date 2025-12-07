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

  def save(project)
    records[project.name] = project
  end

  def exists_with_name?(name)
    records.values.any? { |proj| proj.name == name }
  end

  def link_subordinate(parent_id:, child:, order:)
    ensure_single_parent!(child: child, parent_id: parent_id)
    relationships << { parent_id:, child:, child_key: child_key(child), order: }
  end

  def subordinate_relationships_for(parent_id:)
    relationships.select { |rel| rel[:parent_id] == parent_id }
  end

  def next_subordinate_order(parent_id:)
    max = subordinate_relationships_for(parent_id: parent_id).map { |rel| rel[:order] }.max
    max ? max + 1 : 0
  end

  private

  attr_reader :records, :relationships

  def child_key(child)
    child.respond_to?(:name) ? child.name : child.object_id
  end

  def ensure_single_parent!(child:, parent_id:)
    key = child_key(child)
    existing = relationships.find { |rel| rel[:child_key] == key }
    return unless existing && existing[:parent_id] != parent_id

    raise StandardError, 'child project already has a parent'
  end
end
