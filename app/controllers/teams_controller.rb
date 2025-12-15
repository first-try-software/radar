class TeamsController < ApplicationController
  SORT_OPTIONS = %w[alphabet health].freeze
  DEFAULT_SORT = 'alphabet'.freeze

  def index
    @sort_by = SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @sort_dir = params[:dir] == 'desc' ? 'desc' : 'asc'

    @teams = sorted_teams(@sort_by, @sort_dir)

    respond_to do |format|
      format.html
      format.json { render json: @teams.map { |t| team_json(t) }, status: :ok }
    end
  end

  def show
    result = team_actions.find_team.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @team = result.value
          @team_record = TeamRecord.find(params[:id])
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
          @sort_by = DEFAULT_SORT
          @sort_dir = 'asc'
          @teams = sorted_teams(@sort_by, @sort_dir)
          @errors = result.errors
          render :index, status: :unprocessable_content
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
          @team = result.value
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

  def team_json(team_record)
    {
      name: team_record.name,
      mission: team_record.mission,
      vision: team_record.vision,
      point_of_contact: team_record.point_of_contact,
      archived: team_record.archived
    }
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

  def root_teams
    TeamRecord.left_outer_joins(:parent_relationships).where(teams_teams: { parent_id: nil })
  end

  def sorted_teams(sort_by, direction)
    base = root_teams

    case sort_by
    when 'health'
      sort_by_health(base, direction)
    else # alphabet
      dir = direction == 'desc' ? 'DESC' : 'ASC'
      base.order(Arel.sql("teams.archived ASC, teams.name #{dir}"))
    end
  end

  def sort_by_health(teams, direction)
    asc_scores = { on_track: 1, at_risk: 2, off_track: 3 }
    desc_scores = { off_track: 1, at_risk: 2, on_track: 3 }
    scores = direction == 'desc' ? desc_scores : asc_scores

    teams_with_health = teams.map do |record|
      result = team_actions.find_team.perform(id: record.id)
      health = result.success? ? result.value.health : :not_available
      score = scores[health] || 999
      [record, score]
    end

    sorted = teams_with_health.sort_by do |record, score|
      [record.archived ? 1 : 0, score, record.name]
    end

    sorted.map(&:first)
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
end
