class ProjectRecord < ApplicationRecord
  self.table_name = 'projects'

  ALLOWED_STATES = %w[new todo in_progress blocked on_hold done].freeze

  has_many :subordinate_relationships,
           class_name: 'ProjectsProjectRecord',
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :destroy

  has_many :children, through: :subordinate_relationships, source: :child

  has_one :parent_relationship,
          class_name: 'ProjectsProjectRecord',
          foreign_key: :child_id,
          inverse_of: :child,
          dependent: :destroy

  has_one :parent, through: :parent_relationship, source: :parent

  has_many :health_updates,
           class_name: 'HealthUpdateRecord',
           foreign_key: :project_id,
           inverse_of: :project,
           dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :current_state, presence: true, inclusion: { in: ALLOWED_STATES }
end
