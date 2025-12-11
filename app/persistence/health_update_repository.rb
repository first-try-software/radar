require Rails.root.join('lib/domain/projects/health_update')

class HealthUpdateRepository
  def save(update)
    HealthUpdateRecord.create!(
      project_id: update.project_id,
      date: update.date,
      health: update.health,
      description: update.description
    )

    update
  end

  def all_for_project(project_id)
    HealthUpdateRecord
      .where(project_id: project_id)
      .order(:date)
      .map { |record| build_entity(record) }
  end

  def weekly_for_project(project_id)
    all_for_project(project_id)
  end

  private

  def build_entity(record)
    HealthUpdate.new(
      project_id: record.project_id.to_s,
      date: record.date,
      health: record.health.to_sym,
      description: record.description
    )
  end
end
