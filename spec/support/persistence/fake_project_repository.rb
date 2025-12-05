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
    relationships << { parent_id:, child:, order: }
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
end
