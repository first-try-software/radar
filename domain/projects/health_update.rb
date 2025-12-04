class HealthUpdate
  attr_reader :project_id, :date, :health, :description

  def initialize(project_id:, date:, health:, description: nil)
    @project_id = project_id
    @date = date
    @health = health
    @description = description&.to_s
  end
end
