require Rails.root.join('lib/domain/projects/health_update')

class HealthUpdateRepository
  def save(update)
    HealthUpdateRecord.transaction do
      project_id = update.project_id.to_i
      HealthUpdateRecord.where(project_id: project_id, date: update.date).delete_all
      HealthUpdateRecord.create!(
        project_id: project_id,
        date: update.date,
        health: update.health,
        description: update.description
      )
    end

    update
  end

  def all_for_project(project_id)
    HealthUpdateRecord
      .where(project_id: project_id)
      .order(:date, :created_at, :id)
      .map { |record| build_entity(record) }
  end

  def weekly_for_project(project_id)
    updates = all_for_project(project_id)
    bucket_by_week(updates)
  end

  def all
    HealthUpdateRecord.order(date: :desc).map { |record| build_entity(record) }
  end

  def latest_for_project(project_id)
    record = HealthUpdateRecord.where(project_id: project_id).order(date: :desc).first
    record ? build_entity(record) : nil
  end

  private

  def bucket_by_week(updates)
    mondays = last_six_mondays
    return [] if mondays.empty?

    weekly_points = mondays.map do |monday|
      updates_before = updates.select { |u| u.date <= monday }

      if updates_before.empty?
        HealthUpdate.new(
          project_id: nil,
          date: monday,
          health: :not_available,
          description: nil
        )
      else
        latest = updates_before.max_by(&:date)
        HealthUpdate.new(
          project_id: latest.project_id,
          date: monday,
          health: latest.health,
          description: latest.description
        )
      end
    end

    current_week_update = latest_update_after_monday(updates, mondays.last)
    weekly_points << current_week_update if current_week_update

    weekly_points
  end

  def latest_update_after_monday(updates, last_monday)
    return nil unless last_monday

    updates_after = updates.select { |u| u.date > last_monday }
    return nil if updates_after.empty?

    updates_after.max_by(&:date)
  end

  def last_six_mondays
    today = Date.current
    most_recent_monday = today - ((today.wday - 1) % 7)
    most_recent_monday -= 7 if most_recent_monday >= today

    (0...6).map { |i| most_recent_monday - (i * 7) }.reverse
  end

  def build_entity(record)
    HealthUpdate.new(
      project_id: record.project_id.to_s,
      date: record.date,
      health: record.health.to_sym,
      description: record.description
    )
  end
end
