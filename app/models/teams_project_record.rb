class TeamsProjectRecord < ApplicationRecord
  self.table_name = 'teams_projects'

  belongs_to :team, class_name: 'TeamRecord', inverse_of: :owned_project_relationships
  belongs_to :project, class_name: 'ProjectRecord', inverse_of: false

  validates :order, presence: true
  validates :project_id, uniqueness: true # A project can only be owned by one team
end
