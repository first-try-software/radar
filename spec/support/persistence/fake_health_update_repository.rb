class FakeHealthUpdateRepository
  def initialize(records: [])
    @records = records.dup
  end

  def save(health_update)
    records << health_update
    health_update
  end

  def all_for_project(project_id)
    records.select { |update| update.project_id == project_id }
  end

  private

  attr_reader :records
end
