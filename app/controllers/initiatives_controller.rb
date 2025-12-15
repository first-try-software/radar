class InitiativesController < ApplicationController
  SORT_OPTIONS = %w[alphabet state health].freeze
  DEFAULT_SORT = 'alphabet'.freeze

  def index
    @sort_by = SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @sort_dir = params[:dir] == 'desc' ? 'desc' : 'asc'

    @initiatives = sorted_initiatives(@sort_by, @sort_dir)

    respond_to do |format|
      format.html
      format.json { render json: @initiatives.map { |init| initiative_json(init) }, status: :ok }
    end
  end

  def show
    result = initiative_actions.find_initiative.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @initiative = result.value
          @initiative_record = InitiativeRecord.find(params[:id])
          populate_dashboard_data(@initiative)
          render :show
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create
    result = initiative_actions.create_initiative.perform(**create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          record = InitiativeRecord.find_by(name: result.value.name)
          redirect_to(initiative_path(record), notice: 'Initiative created')
        else
          @sort_by = DEFAULT_SORT
          @sort_dir = 'asc'
          @initiatives = sorted_initiatives(@sort_by, @sort_dir)
          @errors = result.errors
          render :index, status: :unprocessable_content
        end
      end
    end
  end

  def update
    record = InitiativeRecord.find(params[:id])
    attrs = {
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact
    }.merge(update_params.compact)

    result = initiative_actions.update_initiative.perform(id: params[:id], **attrs)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Initiative updated')
        else
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = result.value || find_domain_initiative(@initiative_record.id)
          @errors = result.errors
          populate_dashboard_data(@initiative)
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def set_state
    cascade = params[:cascade] == 'true' || params[:cascade] == true
    result = initiative_actions.set_initiative_state.perform(
      id: params[:id],
      state: params[:state],
      cascade: cascade
    )

    respond_to do |format|
      format.json do
        if result.success?
          render json: initiative_json(result.value), status: :ok
        else
          render json: { errors: result.errors }, status: error_status(result.errors)
        end
      end
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'State updated')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def archive
    result = initiative_actions.archive_initiative.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Initiative archived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def link_related_project
    result = initiative_actions.link_related_project.perform(
      initiative_id: params[:id],
      project_id: params[:project_id]
    )

    respond_to do |format|
      format.json { render_project_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Project linked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def add_related_project
    project_name = params.dig(:project, :name)

    # First create the project
    create_result = project_actions.create_project.perform(name: project_name)
    unless create_result.success?
      respond_to do |format|
        format.json { render json: { errors: create_result.errors }, status: :unprocessable_content }
        format.html do
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = find_domain_initiative(@initiative_record.id)
          @errors = create_result.errors
          populate_dashboard_data(@initiative)
          render :show, status: :unprocessable_content
        end
      end
      return
    end

    # Find the created project record
    project_record = ProjectRecord.find_by(name: project_name)

    # Link it to the initiative
    link_result = initiative_actions.link_related_project.perform(
      initiative_id: params[:id],
      project_id: project_record.id
    )

    respond_to do |format|
      format.json { render_project_result(link_result, success_status: :created) }
      format.html do
        if link_result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Project added and linked')
        else
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = find_domain_initiative(@initiative_record.id)
          @errors = link_result.errors
          populate_dashboard_data(@initiative)
          render :show, status: :unprocessable_content
        end
      end
    end
  end

  def unlink_related_project
    result = initiative_actions.unlink_related_project.perform(
      initiative_id: params[:id],
      project_id: params[:project_id]
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
          redirect_to(initiative_path(params[:id]), notice: 'Project unlinked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  private

  def initiative_actions
    Rails.application.config.x.initiative_actions
  end

  def project_actions
    Rails.application.config.x.project_actions
  end

  def find_domain_initiative(id)
    result = initiative_actions.find_initiative.perform(id: id)
    result.success? ? result.value : nil
  end

  def render_result(result, success_status: :ok)
    if result.success?
      render json: initiative_json(result.value), status: success_status
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def render_project_result(result, success_status: :ok)
    if result.success?
      render json: project_json(result.value), status: success_status
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def error_status(errors)
    return :not_found if errors.include?('initiative not found')
    return :not_found if errors.include?('project not found')
    return :not_found if errors.include?('project not linked to initiative')

    :unprocessable_content
  end

  def initiative_json(initiative)
    {
      name: initiative.name,
      description: initiative.description,
      point_of_contact: initiative.point_of_contact,
      current_state: initiative.current_state.to_s,
      archived: initiative.archived?
    }
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

  def sorted_initiatives(sort_by, direction)
    base = InitiativeRecord.all

    case sort_by
    when 'health'
      sort_by_health(base, direction)
    when 'state'
      sort_by_state(base, direction)
    else # alphabet
      dir = direction == 'desc' ? 'DESC' : 'ASC'
      base.order(Arel.sql("initiatives.archived ASC, initiatives.name #{dir}"))
    end
  end

  def sort_by_health(initiatives, direction)
    # ASC (best to worst): on_track, at_risk, off_track, not_available
    # DESC (worst to best): off_track, at_risk, on_track, not_available
    asc_scores = { on_track: 1, at_risk: 2, off_track: 3 }
    desc_scores = { off_track: 1, at_risk: 2, on_track: 3 }
    scores = direction == 'desc' ? desc_scores : asc_scores

    initiatives_with_health = initiatives.map do |record|
      result = initiative_actions.find_initiative.perform(id: record.id)
      health = result.success? ? result.value.health : :not_available
      score = scores[health] || 999 # not_available always last
      [record, score]
    end

    sorted = initiatives_with_health.sort_by do |record, score|
      [record.archived ? 1 : 0, score, record.name]
    end

    sorted.map(&:first)
  end

  def sort_by_state(initiatives, direction)
    # State priority order (most active/urgent first, done last)
    # ASC: blocked, in_progress, on_hold, todo, new, done
    # DESC: done, new, todo, on_hold, in_progress, blocked
    asc_scores = { 'blocked' => 1, 'in_progress' => 2, 'on_hold' => 3, 'todo' => 4, 'new' => 5, 'done' => 6 }
    desc_scores = { 'done' => 1, 'new' => 2, 'todo' => 3, 'on_hold' => 4, 'in_progress' => 5, 'blocked' => 6 }
    scores = direction == 'desc' ? desc_scores : asc_scores

    sorted = initiatives.sort_by do |record|
      state_score = scores[record.current_state] || 999
      [record.archived ? 1 : 0, state_score, record.name]
    end

    sorted
  end

  def create_params
    permitted = params.fetch(:initiative, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:description] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    params.fetch(:initiative, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end

  def populate_dashboard_data(initiative)
    return set_empty_dashboard_data unless initiative

    dashboard = InitiativeDashboard.new(
      initiative: initiative,
      health_update_repository: Rails.application.config.x.health_update_repository
    )

    @health_summary = dashboard.health_summary
    @total_active_projects = dashboard.total_active_projects
    @attention_required = dashboard.attention_required
    @on_hold_projects = dashboard.on_hold_projects
    @never_updated_projects = dashboard.never_updated_projects
    @stale_projects_14 = dashboard.stale_projects(days: 14)
    @stale_projects_7 = dashboard.stale_projects_between(min_days: 7, max_days: 14)
  end

  def set_empty_dashboard_data
    @health_summary = { on_track: 0, at_risk: 0, off_track: 0 }
    @total_active_projects = 0
    @attention_required = []
    @on_hold_projects = []
    @never_updated_projects = []
    @stale_projects_14 = []
    @stale_projects_7 = []
  end
end
