class TeamsTeamRecord < ApplicationRecord
  self.table_name = 'teams_teams'

  belongs_to :parent, class_name: 'TeamRecord', inverse_of: :child_relationships
  belongs_to :child, class_name: 'TeamRecord', inverse_of: :parent_relationships

  validates :order, presence: true
  validates :parent_id, uniqueness: { scope: :child_id }
  validates :child_id, uniqueness: true # A team can only have one parent
end


