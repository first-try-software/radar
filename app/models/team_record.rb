class TeamRecord < ApplicationRecord
  self.table_name = 'teams'

  has_many :owned_project_relationships,
           class_name: 'TeamsProjectRecord',
           foreign_key: :team_id,
           inverse_of: :team,
           dependent: :destroy

  has_many :owned_projects, through: :owned_project_relationships, source: :project

  has_many :child_relationships,
           class_name: 'TeamsTeamRecord',
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :destroy

  has_many :subordinate_teams, through: :child_relationships, source: :child

  has_many :parent_relationships,
           class_name: 'TeamsTeamRecord',
           foreign_key: :child_id,
           inverse_of: :child,
           dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
