class ProjectsProjectRecord < ApplicationRecord
  self.table_name = 'projects_projects'

  belongs_to :parent, class_name: 'ProjectRecord', inverse_of: :subordinate_relationships
  belongs_to :child, class_name: 'ProjectRecord', inverse_of: :parent_relationship

  validates :order, presence: true
  validates :child_id, uniqueness: true
  validates :child_id, uniqueness: { scope: :parent_id }
  validates :order, uniqueness: { scope: :parent_id }
end
