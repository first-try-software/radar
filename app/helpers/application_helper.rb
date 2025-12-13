module ApplicationHelper
  WORKING_PROJECT_STATES = [:in_progress, :blocked].freeze

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

  private

  def project_health_value(project_like)
    state = project_state(project_like)
    return :not_available unless WORKING_PROJECT_STATES.include?(state)

    if project_like.respond_to?(:health)
      project_like.health
    else
      domain_project_for(project_like)&.health || :not_available
    end
  end

  def project_state(project_like)
    return nil unless project_like.respond_to?(:current_state)

    project_like.current_state&.to_sym
  end

  def domain_project_for(project_record)
    return project_record if project_record.respond_to?(:health)

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
    return nil unless project.respond_to?(:health_updates_for_tooltip)

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
end
