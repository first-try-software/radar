class InitiativesProjectRecord < ApplicationRecord
  self.table_name = 'initiatives_projects'

  belongs_to :initiative, class_name: 'InitiativeRecord', inverse_of: :related_project_relationships
  belongs_to :project, class_name: 'ProjectRecord', inverse_of: false

  validates :order, presence: true
  validates :project_id, uniqueness: { scope: :initiative_id }
  validates :order, uniqueness: { scope: :initiative_id }
end
