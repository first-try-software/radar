require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#project_breadcrumb' do
    it 'returns home icon breadcrumb when project has no parent or team' do
      project = double('Project', parent: nil, owning_team: nil)

      result = helper.project_breadcrumb(project)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('breadcrumb__link')
    end

    it 'includes home icon and parent project in breadcrumb' do
      parent_record = ProjectRecord.create!(name: 'Parent Project')

      parent = double('Project', name: 'Parent Project', parent: nil, owning_team: nil, id: parent_record.id.to_s)
      child = double('Project', name: 'Child Project', parent: parent, owning_team: nil)

      result = helper.project_breadcrumb(child)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('Parent Project')
    end

    it 'includes owning team in breadcrumb' do
      team_record = TeamRecord.create!(name: 'Platform')

      team = double('Team', name: 'Platform', parent_team: nil, id: team_record.id.to_s)
      project = double('Project', name: 'Feature', parent: nil, owning_team: team)

      result = helper.project_breadcrumb(project)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('Platform')
    end
  end

  describe '#team_breadcrumb' do
    it 'returns home icon breadcrumb when team has no parent' do
      team = double('Team', parent_team: nil)

      result = helper.team_breadcrumb(team)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('breadcrumb__link')
    end

    it 'includes home icon and parent team in breadcrumb' do
      parent_record = TeamRecord.create!(name: 'Engineering')

      parent = double('Team', name: 'Engineering', parent_team: nil, id: parent_record.id.to_s)
      child = double('Team', name: 'Platform', parent_team: parent)

      result = helper.team_breadcrumb(child)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('Engineering')
    end
  end

  describe '#initiative_breadcrumb' do
    it 'returns breadcrumb with home icon for initiatives' do
      initiative = double('Initiative')

      result = helper.initiative_breadcrumb(initiative)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('breadcrumb__link')
    end
  end

  describe '#trend_arrow_svg' do
    it 'returns up arrow SVG for :up direction' do
      result = helper.trend_arrow_svg(:up)

      expect(result).to include('trend-arrow--up')
      expect(result).to include('<svg')
    end

    it 'returns down arrow SVG for :down direction' do
      result = helper.trend_arrow_svg(:down)

      expect(result).to include('trend-arrow--down')
      expect(result).to include('<svg')
    end

    it 'returns stable arrow SVG for :stable direction' do
      result = helper.trend_arrow_svg(:stable)

      expect(result).to include('trend-arrow--stable')
      expect(result).to include('<svg')
    end

    it 'returns stable arrow SVG for unknown direction' do
      result = helper.trend_arrow_svg(:unknown)

      expect(result).to include('trend-arrow--stable')
    end
  end

  describe 'breadcrumb edge cases' do
    it 'returns empty string when crumbs array is empty' do
      result = helper.send(:render_breadcrumb, [])

      expect(result).to eq('')
    end

    it 'handles team hierarchy with parent' do
      parent_record = TeamRecord.create!(name: 'ParentTeam')

      parent = double('Team', name: 'ParentTeam', parent_team: nil, id: parent_record.id.to_s)
      child = double('Team', name: 'ChildOnly', parent_team: parent)

      result = helper.team_breadcrumb(child)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('ParentTeam')
    end

    it 'handles project with parent that has nil parent' do
      parent_record = ProjectRecord.create!(name: 'ParentProject')

      parent = double('Project', name: 'ParentProject', parent: nil, owning_team: nil, id: parent_record.id.to_s)
      child = double('Project', name: 'ChildProject', parent: parent, owning_team: nil)

      result = helper.project_breadcrumb(child)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('ParentProject')
    end

    it 'handles team in hierarchy with nil parent_team' do
      parent_record = TeamRecord.create!(name: 'ParentTeam')

      parent = double('Team', name: 'ParentTeam', parent_team: nil, id: parent_record.id.to_s)
      child = double('Team', name: 'ChildTeam', parent_team: parent)

      result = helper.team_breadcrumb(child)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('ParentTeam')
    end

    it 'handles project with parent' do
      parent_record = ProjectRecord.create!(name: 'ParentProject')

      parent = double('Project', name: 'ParentProject', parent: nil, owning_team: nil, id: parent_record.id.to_s)
      child = double('Project', name: 'ChildOnly', parent: parent, owning_team: nil)

      result = helper.project_breadcrumb(child)

      expect(result).to include('breadcrumb__link--home')
      expect(result).to include('ParentProject')
    end
  end
end
