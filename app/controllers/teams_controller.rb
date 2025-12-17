class TeamsController < ApplicationController
  def show
    result = team_actions.find_team.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @team = result.value
          @team_record = TeamRecord.find(params[:id])
          populate_team_dashboard_data(@team)
          render :show
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create
    result = team_actions.create_team.perform(**create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          record = TeamRecord.find_by(name: result.value.name)
          redirect_to(team_path(record), notice: 'Team created')
        else
          redirect_to(root_path, alert: result.errors.join(', '))
        end
      end
    end
  end

  def update
    record = TeamRecord.find(params[:id])
    attrs = {
      name: record.name,
      mission: record.mission,
      vision: record.vision,
      point_of_contact: record.point_of_contact
    }.merge(update_params.compact)

    result = team_actions.update_team.perform(id: params[:id], **attrs)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(team_path(params[:id]), notice: 'Team updated')
        else
          @team_record = TeamRecord.find(params[:id])
          @team = find_domain_team(@team_record.id)
          populate_team_dashboard_data(@team)
          @errors = result.errors
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def archive
    result = team_actions.archive_team.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(team_path(params[:id]), notice: 'Team archived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def link_owned_project
    result = team_actions.link_owned_project.perform(
      team_id: params[:id],
      project_id: params[:project_id]
    )

    respond_to do |format|
      format.json { render_project_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(team_path(params[:id]), notice: 'Project linked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def add_owned_project
    project_name = params.dig(:project, :name)
    project_description = params.dig(:project, :description) || ''
    project_poc = params.dig(:project, :point_of_contact) || ''

    # First create the project
    create_result = project_actions.create_project.perform(
      name: project_name,
      description: project_description,
      point_of_contact: project_poc
    )
    unless create_result.success?
      respond_to do |format|
        format.json { render json: { errors: create_result.errors }, status: :unprocessable_content }
        format.html do
          @team_record = TeamRecord.find(params[:id])
          @team = find_domain_team(@team_record.id)
          populate_team_dashboard_data(@team)
          @errors = create_result.errors
          render :show, status: :unprocessable_content
        end
      end
      return
    end

    # Find the created project record
    project_record = ProjectRecord.find_by(name: project_name)

    # Link it to the team
    link_result = team_actions.link_owned_project.perform(
      team_id: params[:id],
      project_id: project_record.id
    )

    respond_to do |format|
      format.json { render_project_result(link_result, success_status: :created) }
      format.html do
        if link_result.success?
          redirect_to(team_path(params[:id]), notice: 'Project added and linked')
        else
          @team_record = TeamRecord.find(params[:id])
          @team = find_domain_team(@team_record.id)
          populate_team_dashboard_data(@team)
          @errors = link_result.errors
          render :show, status: :unprocessable_content
        end
      end
    end
  end

  def add_subordinate_team
    result = team_actions.create_subordinate_team.perform(
      parent_id: params[:id],
      name: params.dig(:team, :name),
      mission: params.dig(:team, :mission) || '',
      vision: params.dig(:team, :vision) || '',
      point_of_contact: params.dig(:team, :point_of_contact) || ''
    )

    respond_to do |format|
      format.json do
        if result.success?
          render json: team_json_from_domain(result.value), status: :created
        else
          render json: { errors: result.errors }, status: error_status(result.errors)
        end
      end
      format.html do
        if result.success?
          record = TeamRecord.find_by(name: result.value.name)
          redirect_to(team_path(record), notice: 'Subordinate team created')
        else
          @team_record = TeamRecord.find(params[:id])
          @team = find_domain_team(@team_record.id)
          populate_team_dashboard_data(@team)
          @errors = result.errors
          render :show, status: :unprocessable_content
        end
      end
    end
  end

  private

  def team_actions
    Rails.application.config.x.team_actions
  end

  def project_actions
    Rails.application.config.x.project_actions
  end

  def find_domain_team(id)
    result = team_actions.find_team.perform(id: id)
    result.success? ? result.value : nil
  end

  def render_result(result, success_status: :ok)
    if result.success?
      render json: team_json_from_domain(result.value), status: success_status
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
    errors = Array(errors)
    return :not_found if errors.include?('team not found')
    return :not_found if errors.include?('project not found')

    :unprocessable_content
  end

  def team_json_from_domain(team)
    {
      name: team.name,
      mission: team.mission,
      vision: team.vision,
      point_of_contact: team.point_of_contact,
      archived: team.archived?
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

  def create_params
    permitted = params.fetch(:team, {}).permit(:name, :mission, :vision, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:mission] ||= ''
    permitted[:vision] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    params.fetch(:team, {}).permit(:name, :mission, :vision, :point_of_contact).to_h.symbolize_keys
  end

  def populate_team_dashboard_data(team)
    return set_empty_team_dashboard_data unless team

    health_update_repo = Rails.application.config.x.health_update_repository

    dashboard = TeamDashboard.new(
      team: team,
      health_update_repository: health_update_repo
    )

    @health_summary = dashboard.health_summary
    @total_active_projects = dashboard.total_active_projects
    @attention_required = dashboard.attention_required
    @on_hold_projects = dashboard.on_hold_projects
    @never_updated_projects = dashboard.never_updated_projects
    @stale_projects_14 = dashboard.stale_projects(days: 14)
    @stale_projects_7 = dashboard.stale_projects_between(min_days: 7, max_days: 14)

    # Global search data
    @teams = team_repository.all_active_roots
    @initiatives = initiative_repository.all_active_roots
    @all_projects = project_repository.all_active_roots

    # Trend data
    trend_service = TeamTrendService.new(
      team: team,
      health_update_repository: health_update_repo
    )
    trend_result = trend_service.call

    @trend_data = trend_result[:trend_data]
    @trend_direction = trend_result[:trend_direction]
    @trend_delta = trend_result[:trend_delta]
    @weeks_of_data = trend_result[:weeks_of_data]
    @confidence_score = trend_result[:confidence_score]
    @confidence_level = trend_result[:confidence_level]
  end

  def set_empty_team_dashboard_data
    @health_summary = { on_track: 0, at_risk: 0, off_track: 0 }
    @total_active_projects = 0
    @attention_required = []
    @on_hold_projects = []
    @never_updated_projects = []
    @stale_projects_14 = []
    @stale_projects_7 = []
    @teams = []
    @initiatives = []
    @all_projects = []
    @trend_data = []
    @trend_direction = :stable
    @trend_delta = 0.0
    @weeks_of_data = 0
    @confidence_score = 0
    @confidence_level = :low
  end

  def team_repository
    Rails.application.config.x.team_repository
  end

  def initiative_repository
    Rails.application.config.x.initiative_repository
  end

  def project_repository
    Rails.application.config.x.project_repository
  end

end
