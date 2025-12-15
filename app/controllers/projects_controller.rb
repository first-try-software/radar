class ProjectsController < ApplicationController
  SORT_OPTIONS = %w[alphabet state health updated].freeze
  DEFAULT_SORT = 'alphabet'.freeze
  HEALTH_FILTERS = %w[on_track at_risk off_track].freeze

  def index
    @sort_by = SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @sort_dir = params[:dir] == 'desc' ? 'desc' : 'asc'
    @health_filter = HEALTH_FILTERS.include?(params[:health]) ? params[:health].to_sym : nil
    @initiative_filter = find_initiative_filter

    @projects = sorted_projects(@sort_by, @sort_dir)
    @projects = filter_by_initiative(@projects, @initiative_filter) if @initiative_filter
    @projects = filter_by_health(@projects, @health_filter) if @health_filter

    respond_to do |format|
      format.html
      format.json { render json: @projects.map { |proj| project_json(proj) }, status: :ok }
    end
  end

  def show
    result = project_actions.find_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @project = result.value
          @project_record = ProjectRecord.find(params[:id])
          prepare_health_form(project: @project)
          render :show
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create
    result = project_actions.create_project.perform(**create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          record = ProjectRecord.find_by(name: result.value.name)
          redirect_to(project_path(record), notice: 'Project created')
        else
          @projects = root_projects.order(:name)
          @errors = result.errors
          render :index, status: :unprocessable_content
        end
      end
    end
  end

  def update
    record = ProjectRecord.find(params[:id])
    attrs = {
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact
    }.merge(update_params.compact)

    result = project_actions.update_project.perform(id: params[:id], **attrs)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project updated')
        else
          @project_record = ProjectRecord.find(params[:id])
          @project = result.value
          @errors = result.errors
          prepare_health_form(project: @project)
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def set_state
    result = project_actions.set_project_state.perform(id: params[:id], state: params[:state])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'State updated')
        else
          @project_record = ProjectRecord.find_by(id: params[:id])
          return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @project_record

          @project = project_actions.find_project.perform(id: params[:id]).value
          @errors = result.errors
          prepare_health_form(project: @project)
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def archive
    result = project_actions.archive_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project archived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def unarchive
    result = project_actions.unarchive_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project unarchived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create_subordinate
    result = project_actions.create_subordinate_project.perform(parent_id: params[:id], **create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Child project created')
        else
          if result.errors.include?('project not found')
            render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
          else
            @project_record = ProjectRecord.find_by(id: params[:id])
            return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @project_record

            @project = project_actions.find_project.perform(id: params[:id]).value
            @errors = result.errors
            prepare_health_form(project: @project)
            render :show, status: error_status(result.errors)
          end
        end
      end
    end
  end

  def unlink_subordinate
    result = project_actions.unlink_subordinate_project.perform(
      parent_id: params[:id],
      child_id: params[:child_id]
    )

    respond_to do |format|
      format.json do
        if result.success?
          render json: { success: true }, status: :ok
        else
          render json: { errors: result.errors }, status: error_status(result.errors)
        end
      end
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project unlinked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def link_subordinate
    result = project_actions.link_subordinate_project.perform(
      parent_id: params[:id],
      child_id: params[:child_id]
    )

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project linked')
        else
          if result.errors.include?('parent project not found') || result.errors.include?('child project not found')
            render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
          else
            # Parent exists if we get here (only 'project already has a parent' error reaches this branch)
            @project_record = ProjectRecord.find(params[:id])
            @project = project_actions.find_project.perform(id: params[:id]).value
            @errors = result.errors
            prepare_health_form(project: @project)
            render :show, status: :unprocessable_content
          end
        end
      end
    end
  end

  def create_health_update
    attrs = health_update_attributes
    result = project_actions.record_project_health_update.perform(
      project_id: params[:id],
      date: attrs[:date],
      health: attrs[:health],
      description: attrs[:description]
    )

    respond_to do |format|
      format.json { render_health_update_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Health updated')
        else
          render_health_update_errors(result)
        end
      end
    end
  end

  private

  def project_actions
    Rails.application.config.x.project_actions
  end

  def render_result(result, success_status: :ok)
    if result.success?
      render json: project_json(result.value), status: success_status
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def error_status(errors)
    return :not_found if errors.include?('project not found')
    return :not_found if errors.include?('parent project not found')
    return :not_found if errors.include?('child project not found')
    return :not_found if errors.include?('project not linked to parent')

    :unprocessable_content
  end

  def project_json(project)
    {
      name: project.name,
      description: project.description,
      point_of_contact: project.point_of_contact,
      current_state: project.current_state,
      archived: project.archived?
    }
  end

  def root_projects
    ProjectRecord.left_outer_joins(:parent_relationship).where(projects_projects: { parent_id: nil })
  end

  def sorted_projects(sort_by, direction)
    dir = direction == 'desc' ? 'DESC' : 'ASC'

    base = root_projects.left_joins(:health_updates).group(:id)

    case sort_by
    when 'health'
      sort_by_health(base, direction)
    when 'state'
      sort_by_state(base, direction)
    when 'updated'
      sort_by_updated(base, direction)
    else # alphabet
      base.order(Arel.sql("projects.archived ASC, projects.name #{dir}"))
    end
  end

  def sort_by_health(projects, direction)
    # ASC (best to worst): on_track, at_risk, off_track, not_available
    # DESC (worst to best): off_track, at_risk, on_track, not_available
    asc_scores = { on_track: 1, at_risk: 2, off_track: 3 }
    desc_scores = { off_track: 1, at_risk: 2, on_track: 3 }
    scores = direction == 'desc' ? desc_scores : asc_scores

    projects_with_health = projects.map do |record|
      result = project_actions.find_project.perform(id: record.id)
      health = result.success? ? result.value.health : :not_available
      score = scores[health] || 999 # not_available always last
      [record, score]
    end

    sorted = projects_with_health.sort_by do |record, score|
      [record.archived ? 1 : 0, score, record.name]
    end

    sorted.map(&:first)
  end

  def sort_by_state(projects, direction)
    # State priority order (most active/urgent first, done last)
    # ASC: blocked, in_progress, on_hold, todo, new, done
    # DESC: done, new, todo, on_hold, in_progress, blocked
    asc_scores = { 'blocked' => 1, 'in_progress' => 2, 'on_hold' => 3, 'todo' => 4, 'new' => 5, 'done' => 6 }
    desc_scores = { 'done' => 1, 'new' => 2, 'todo' => 3, 'on_hold' => 4, 'in_progress' => 5, 'blocked' => 6 }
    scores = direction == 'desc' ? desc_scores : asc_scores

    sorted = projects.sort_by do |record|
      state_score = scores[record.current_state] || 999
      [record.archived ? 1 : 0, state_score, record.name]
    end

    sorted
  end

  def sort_by_updated(projects, direction)
    # Sort by most recent health update date, with created_at as tiebreaker
    # Projects without health updates go last regardless of direction
    projects_with_dates = projects.map do |record|
      latest_update = record.health_updates.order(date: :desc, created_at: :desc).first
      [record, latest_update&.date, latest_update&.created_at]
    end

    sorted = projects_with_dates.sort_by do |record, date, created_at|
      archived_rank = record.archived ? 1 : 0

      if date.nil?
        # No health updates - always last
        date_rank = direction == 'desc' ? [2, nil, nil] : [2, nil, nil]
      else
        # Has health updates - sort by date and created_at
        created_at_int = created_at.to_i
        if direction == 'desc'
          # Most recent first: negate the values for descending
          date_rank = [0, -date.to_time.to_i, -created_at_int]
        else
          # Oldest first
          date_rank = [0, date.to_time.to_i, created_at_int]
        end
      end

      [archived_rank, date_rank, record.name]
    end

    sorted.map(&:first)
  end

  def filter_by_health(projects, health_filter)
    projects.select do |record|
      result = project_actions.find_project.perform(id: record.id)
      result.success? && result.value.health == health_filter
    end
  end

  def find_initiative_filter
    return nil unless params[:initiative].present?

    InitiativeRecord.find_by(id: params[:initiative])
  end

  def filter_by_initiative(projects, initiative)
    initiative_project_ids = initiative.related_projects.pluck(:id)
    projects.select { |record| initiative_project_ids.include?(record.id) }
  end

  def create_params
    permitted = params.fetch(:project, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:description] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    params.fetch(:project, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end

  def health_update_params
    params.fetch(:health_update, {}).permit(:date, :health, :description)
  end

  def health_update_attributes
    permitted = health_update_params.to_h.symbolize_keys
    {
      date: parse_date(permitted[:date]),
      health: permitted[:health],
      description: permitted[:description]
    }
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return nil if value.nil? || value == ''

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def render_health_update_result(result)
    if result.success?
      project_id = result.value.project_id
      project = project_actions.find_project.perform(id: project_id).value
      render json: { health: project.health }, status: :created
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def render_health_update_errors(result)
    if result.errors.include?('project not found')
      render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
      return
    end

    @project_record = ProjectRecord.find_by(id: params[:id])
    return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @project_record

    @project = project_actions.find_project.perform(id: params[:id]).value
    @errors = result.errors
    prepare_health_form(project: @project, open: true)
    render :show, status: error_status(result.errors)
  end

  def prepare_health_form(project:, open: false)
    @health_options = health_options
    @selected_health = selected_health_for(project)
    @show_health_update_form = open
  end

  def health_options
    RecordProjectHealthUpdate::ALLOWED_HEALTHS
  end

  def selected_health_for(project)
    return health_options.first unless project

    health_options.include?(project.health) ? project.health : health_options.first
  end
end
