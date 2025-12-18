# Sorts projects using the canonical sort order:
# 1. State: blocked → in_progress → new → todo → on_hold → done
# 2. Health: off_track → at_risk → on_track → not_available
# 3. Last update date: oldest first (staler projects first)
# 4. Name: alphabetical
class ProjectSorter
  STATE_ORDER = {
    blocked: 0,
    in_progress: 1,
    new: 2,
    todo: 3,
    on_hold: 4,
    done: 5
  }.freeze

  HEALTH_ORDER = {
    off_track: 0,
    at_risk: 1,
    on_track: 2,
    not_available: 3
  }.freeze

  def initialize(projects)
    @projects = projects
  end

  def sorted
    @projects.sort_by do |project|
      [
        state_rank(project),
        health_rank(project),
        last_update_rank(project),
        name_rank(project)
      ]
    end
  end

  private

  def state_rank(project)
    state = project.current_state || :done
    STATE_ORDER[state] || 99
  end

  def health_rank(project)
    health = project.health || :not_available
    HEALTH_ORDER[health] || 99
  end

  def last_update_rank(project)
    last_update = project.latest_health_update
    # Ascending date means oldest first (smaller timestamp = earlier in sort)
    # Projects with no update get 0, so they appear first (stalest)
    last_update&.date ? last_update.date.to_time.to_i : 0
  end

  def name_rank(project)
    project.name.to_s.downcase
  end
end
