class FakeInitiativeRepository
  def initialize(initiatives: {})
    @records = initiatives
    @relationships = []
  end

  def find(id)
    records[id]
  end

  def update(id:, initiative:)
    records[id] = initiative
  end

  def save(initiative)
    records[initiative.name] = initiative
  end

  def exists_with_name?(name)
    records.values.any? { |initiative| initiative.name == name }
  end

  def link_related_project(initiative_id:, project:, order:)
    relationships << { initiative_id:, project:, order: }
  end

  def related_projects_for(initiative_id:)
    relationships.select { |rel| rel[:initiative_id] == initiative_id }
  end

  def next_related_project_order(initiative_id:)
    max = related_projects_for(initiative_id: initiative_id).map { |rel| rel[:order] }.max
    max ? max + 1 : 0
  end

  def related_project_exists?(initiative_id:, project_id:)
    relationships.any? { |rel| rel[:initiative_id] == initiative_id && rel[:project].name == project_id }
  end

  def unlink_related_project(initiative_id:, project_id:)
    relationships.reject! { |rel| rel[:initiative_id] == initiative_id && rel[:project].name == project_id }
  end

  private

  attr_reader :records, :relationships
end
