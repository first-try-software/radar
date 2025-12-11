module ApplicationHelper
  WORKING_PROJECT_STATES = [:in_progress, :blocked].freeze

  def project_health_indicator(project_like)
    health_value = project_health_value(project_like)
    label = project_health_label(health_value)

    content_tag(
      :span,
      '',
      class: "project-health project-health--#{health_value}",
      title: label,
      aria: { label: label }
    )
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
end
