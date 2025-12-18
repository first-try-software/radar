module ApplicationHelper
  def team_health_indicator(team_like, with_tooltip: false)
    health_value = team_health_value(team_like)
    label = project_health_label(health_value)

    indicator = content_tag(
      :span,
      '',
      class: "project-health project-health--#{health_value}",
      aria: { label: label }
    )

    if with_tooltip
      if team_like.respond_to?(:owned_projects)
        owned = team_like.owned_projects
        if owned.respond_to?(:any?) && owned.any?
          return health_indicator_with_owned_projects_tooltip(indicator, health_value, owned)
        end
      end
    end

    indicator
  end

  def initiative_health_indicator(initiative_like, with_tooltip: false)
    health_value = initiative_health_value(initiative_like)
    label = project_health_label(health_value)

    indicator = content_tag(
      :span,
      '',
      class: "project-health project-health--#{health_value}",
      aria: { label: label }
    )

    if with_tooltip
      if initiative_like.respond_to?(:related_projects)
        related = initiative_like.related_projects
        if related.respond_to?(:any?) && related.any?
          return health_indicator_with_related_projects_tooltip(indicator, health_value, related)
        end
      end
    end

    indicator
  end

  def project_health_indicator(project_like, with_tooltip: false)
    health_value = project_health_value(project_like)
    label = project_health_label(health_value)

    indicator = content_tag(
      :span,
      '',
      class: "project-health project-health--#{health_value}",
      aria: { label: label }
    )

    if with_tooltip
      if project_like.respond_to?(:children_health_for_tooltip)
        children_health = project_like.children_health_for_tooltip
        if children_health
          return health_indicator_with_children_tooltip(indicator, health_value, children_health)
        end
      end

      if project_like.respond_to?(:health_updates_for_tooltip)
        latest_update = latest_health_update_for(project_like)
        if latest_update
          return health_indicator_with_tooltip(indicator, latest_update)
        end
      end
    end

    indicator
  end

  def project_health_trend(project, interactive: true)
    return nil unless project.respond_to?(:health_trend)

    trend = project.health_trend
    return nil if trend.empty?

    content_tag(:div, class: 'health-trend-list') do
      safe_join(
        trend.map do |update|
          tag_type = interactive ? :button : :div
          tag_options = { class: 'health-trend-item' }
          tag_options[:type] = 'button' if interactive
          tag_options[:data] = { trend_date: update.date.to_s, trend_health: update.health } if interactive

          content_tag(tag_type, **tag_options) do
            dot = content_tag(
              :span,
              '',
              class: "health-trend-list__dot health-trend-list__dot--#{update.health}",
              aria: { label: "#{update.date.strftime('%-m/%d')}: #{project_health_label(update.health)}" }
            )
            tooltip = content_tag(:div, class: 'health-trend-tooltip') do
              date_line = content_tag(:div, update.date.strftime('%-m/%d'), class: 'health-trend-tooltip__date')
              health_line = content_tag(:div, project_health_label(update.health), class: 'health-trend-tooltip__health')
              desc_line = if update.description.present?
                            content_tag(:div, update.description, class: 'health-trend-tooltip__desc')
                          else
                            ''.html_safe
                          end
              safe_join([date_line, health_line, desc_line])
            end
            safe_join([dot, tooltip])
          end
        end
      )
    end
  end

  def project_state_for(project_like)
    # Get the derived state from domain project (handles parent/child rollup)
    if project_like.is_a?(Project)
      project_like.current_state
    elsif project_like.respond_to?(:id)
      domain_project = domain_project_for(project_like)
      domain_project&.current_state || project_like.current_state.to_sym
    else
      project_like.current_state
    end
  end

  def project_state_label(project_like)
    state = project_state_for(project_like)
    state.to_s.tr('_', ' ').titleize
  end

  def sort_projects_canonical(projects)
    ProjectSorter.new(projects).sorted
  end

  def project_sort_data(project_like)
    domain_project = if project_like.is_a?(Project)
                       project_like
                     elsif project_like.respond_to?(:id)
                       domain_project_for(project_like)
                     end

    state = domain_project&.current_state || project_like.current_state.to_sym
    health = domain_project&.health || :not_available

    # State scores: blocked=1, in_progress=2, on_hold=3, todo=4, new=5, done=6
    state_scores = { blocked: 1, in_progress: 2, on_hold: 3, todo: 4, new: 5, done: 6 }
    state_score = state_scores[state] || 99

    # Health scores: on_track=1, at_risk=2, off_track=3, not_available=99
    health_scores = { on_track: 1, at_risk: 2, off_track: 3, not_available: 99 }
    health_score = health_scores[health] || 99

    # Updated date: latest health update or created_at
    updated_at = if domain_project&.respond_to?(:health_updates_for_tooltip)
                   latest = domain_project.health_updates_for_tooltip&.last
                   latest&.date&.to_s || project_like.created_at.to_s
                 else
                   project_like.created_at.to_s
                 end

    name = project_like.respond_to?(:name) ? project_like.name : ''

    {
      name: name.downcase,
      state_score: state_score,
      health_score: health_score,
      updated_at: updated_at
    }
  end

  def team_sort_data(team_like)
    health = team_health_value(team_like)

    # Health scores: on_track=1, at_risk=2, off_track=3, not_available=99
    health_scores = { on_track: 1, at_risk: 2, off_track: 3, not_available: 99 }
    health_score = health_scores[health] || 99

    name = team_like.respond_to?(:name) ? team_like.name : ''

    {
      name: name.downcase,
      health_score: health_score
    }
  end

  # Breadcrumb helpers

  def project_breadcrumb(project, project_record)
    crumbs = [{ name: 'Status', path: root_path }]

    # Collect project ancestors
    project_ancestors = collect_project_ancestors(project)

    # Find owning team from root ancestor or current project
    root_project = project_ancestors.last || project
    if root_project.respond_to?(:owning_team) && root_project.owning_team
      team_crumbs = build_team_hierarchy_crumbs(root_project.owning_team)
      crumbs.concat(team_crumbs)
    end

    # Add project hierarchy (parents) in root-first order
    project_ancestors.reverse.each do |ancestor|
      ancestor_record = ProjectRecord.find_by(name: ancestor.name)
      crumbs << { name: ancestor.name, path: project_path(ancestor_record) } if ancestor_record
    end

    render_breadcrumb(crumbs)
  end

  def team_breadcrumb(team, team_record)
    crumbs = [{ name: 'Status', path: root_path }]

    # Add parent team hierarchy
    if team.respond_to?(:parent_team) && team.parent_team
      parent_crumbs = build_team_hierarchy_crumbs(team.parent_team)
      crumbs.concat(parent_crumbs)
    end

    render_breadcrumb(crumbs)
  end

  def initiative_breadcrumb(initiative, initiative_record)
    crumbs = [{ name: 'Status', path: root_path }]
    render_breadcrumb(crumbs)
  end

  def trend_arrow_svg(direction)
    case direction
    when :up
      '<svg class="trend-arrow trend-arrow--up" viewBox="0 0 16 16" fill="currentColor"><path d="M8 3L14 11H2L8 3Z"/></svg>'.html_safe
    when :down
      '<svg class="trend-arrow trend-arrow--down" viewBox="0 0 16 16" fill="currentColor"><path d="M8 13L2 5H14L8 13Z"/></svg>'.html_safe
    else
      '<svg class="trend-arrow trend-arrow--stable" viewBox="0 0 16 16" fill="currentColor"><path d="M13 7L13 9L3 9L3 7L13 7Z"/></svg>'.html_safe
    end
  end

  private

  def project_health_value(project_like)
    if project_like.respond_to?(:health)
      project_like.health
    else
      domain_project_for(project_like)&.health || :not_available
    end
  end

  def domain_project_for(project_record)
    cache_key = project_record.respond_to?(:id) ? project_record.id.to_s : nil
    @_domain_project_cache ||= {}

    if cache_key && @_domain_project_cache.key?(cache_key)
      return @_domain_project_cache[cache_key]
    end

    result = Rails.application.config.x.project_actions.find_project.perform(id: cache_key)
    project = result.success? ? result.value : nil

    @_domain_project_cache[cache_key] = project if cache_key
    project
  end

  def project_health_label(health_value)
    case health_value
    when :on_track
      'On Track'
    when :at_risk
      'At Risk'
    when :off_track
      'Off Track'
    else
      'Health Not Available'
    end
  end

  def latest_health_update_for(project)
    project.health_updates_for_tooltip&.last
  end

  def health_indicator_with_tooltip(indicator, update)
    content_tag(:div, class: 'health-indicator-wrapper') do
      tooltip = health_tooltip(update)
      safe_join([indicator, tooltip])
    end
  end

  def health_indicator_with_children_tooltip(indicator, rollup_health, children_health)
    content_tag(:div, class: 'health-indicator-wrapper') do
      tooltip = children_health_tooltip(rollup_health, children_health)
      safe_join([indicator, tooltip])
    end
  end

  def children_health_tooltip(rollup_health, children_health)
    content_tag(:div, class: 'health-trend-tooltip health-rollup-tooltip') do
      header = content_tag(:div, project_health_label(rollup_health), class: 'health-trend-tooltip__health')
      children_list = content_tag(:div, class: 'health-rollup-tooltip__children') do
        safe_join(
          children_health.map do |child|
            content_tag(:div, class: 'health-rollup-tooltip__child') do
              child_indicator = content_tag(
                :span,
                '',
                class: "project-health project-health--#{child.health} project-health--tiny",
                aria: { label: project_health_label(child.health) }
              )
              child_name = content_tag(:span, child.name, class: 'health-rollup-tooltip__child-name')
              safe_join([child_indicator, child_name])
            end
          end
        )
      end
      safe_join([header, children_list])
    end
  end

  def health_tooltip(update)
    content_tag(:div, class: 'health-trend-tooltip') do
      date_line = content_tag(:div, update.date.strftime('%-m/%d'), class: 'health-trend-tooltip__date')
      health_line = content_tag(:div, project_health_label(update.health), class: 'health-trend-tooltip__health')
      desc_line = if update.respond_to?(:description) && update.description.present?
                    content_tag(:div, update.description, class: 'health-trend-tooltip__desc')
                  else
                    ''.html_safe
                  end
      safe_join([date_line, health_line, desc_line])
    end
  end

  def initiative_health_value(initiative_like)
    if initiative_like.respond_to?(:health)
      initiative_like.health
    else
      domain_initiative_for(initiative_like)&.health || :not_available
    end
  end

  def domain_initiative_for(initiative_record)
    cache_key = initiative_record.respond_to?(:id) ? initiative_record.id.to_s : nil
    @_domain_initiative_cache ||= {}

    if cache_key && @_domain_initiative_cache.key?(cache_key)
      return @_domain_initiative_cache[cache_key]
    end

    result = Rails.application.config.x.initiative_actions.find_initiative.perform(id: cache_key)
    initiative = result.success? ? result.value : nil

    @_domain_initiative_cache[cache_key] = initiative if cache_key
    initiative
  end

  def health_indicator_with_related_projects_tooltip(indicator, rollup_health, related_projects)
    content_tag(:div, class: 'health-indicator-wrapper') do
      tooltip = related_projects_health_tooltip(rollup_health, related_projects)
      safe_join([indicator, tooltip])
    end
  end

  def related_projects_health_tooltip(rollup_health, related_projects)
    content_tag(:div, class: 'health-trend-tooltip health-rollup-tooltip') do
      header = content_tag(:div, project_health_label(rollup_health), class: 'health-trend-tooltip__health')
      projects_list = content_tag(:div, class: 'health-rollup-tooltip__children') do
        safe_join(
          related_projects.map do |proj|
            proj_health = project_health_value(proj)
            content_tag(:div, class: 'health-rollup-tooltip__child') do
              proj_indicator = content_tag(
                :span,
                '',
                class: "project-health project-health--#{proj_health} project-health--tiny",
                aria: { label: project_health_label(proj_health) }
              )
              proj_name = content_tag(:span, proj.name, class: 'health-rollup-tooltip__child-name')
              safe_join([proj_indicator, proj_name])
            end
          end
        )
      end
      safe_join([header, projects_list])
    end
  end

  def team_health_value(team_like)
    if team_like.respond_to?(:health)
      team_like.health
    else
      domain_team_for(team_like)&.health || :not_available
    end
  end

  def domain_team_for(team_record)
    cache_key = team_record.respond_to?(:id) ? team_record.id.to_s : nil
    @_domain_team_cache ||= {}

    return @_domain_team_cache[cache_key] if @_domain_team_cache.key?(cache_key)

    result = Rails.application.config.x.team_actions.find_team.perform(id: cache_key)
    team = result.success? ? result.value : nil

    @_domain_team_cache[cache_key] = team
    team
  end

  def health_indicator_with_owned_projects_tooltip(indicator, rollup_health, owned_projects)
    content_tag(:div, class: 'health-indicator-wrapper') do
      tooltip = owned_projects_health_tooltip(rollup_health, owned_projects)
      safe_join([indicator, tooltip])
    end
  end

  def owned_projects_health_tooltip(rollup_health, owned_projects)
    content_tag(:div, class: 'health-trend-tooltip health-rollup-tooltip') do
      header = content_tag(:div, project_health_label(rollup_health), class: 'health-trend-tooltip__health')
      projects_list = content_tag(:div, class: 'health-rollup-tooltip__children') do
        safe_join(
          owned_projects.map do |proj|
            proj_health = project_health_value(proj)
            content_tag(:div, class: 'health-rollup-tooltip__child') do
              proj_indicator = content_tag(
                :span,
                '',
                class: "project-health project-health--#{proj_health} project-health--tiny",
                aria: { label: project_health_label(proj_health) }
              )
              proj_name = content_tag(:span, proj.name, class: 'health-rollup-tooltip__child-name')
              safe_join([proj_indicator, proj_name])
            end
          end
        )
      end
      safe_join([header, projects_list])
    end
  end

  private

  def build_team_hierarchy_crumbs(team)
    crumbs = []
    current = team

    # Collect ancestors
    ancestors = []
    while current
      ancestors << current
      current = current.respond_to?(:parent_team) ? current.parent_team : nil
    end

    # Reverse to get root-first order
    ancestors.reverse.each do |t|
      team_record = TeamRecord.find_by(name: t.name)
      crumbs << { name: t.name, path: team_path(team_record) } if team_record
    end

    crumbs
  end

  def collect_project_ancestors(project)
    ancestors = []
    current = project.respond_to?(:parent) ? project.parent : nil

    while current
      ancestors << current
      current = current.respond_to?(:parent) ? current.parent : nil
    end

    ancestors
  end

  def render_breadcrumb(crumbs)
    return ''.html_safe if crumbs.empty?

    links = crumbs.map do |crumb|
      link_to(crumb[:name], crumb[:path], class: 'breadcrumb__link')
    end

    content_tag(:nav, class: 'breadcrumb', aria: { label: 'Breadcrumb' }) do
      safe_join(links, content_tag(:span, ' / ', class: 'breadcrumb__separator'))
    end
  end
end
