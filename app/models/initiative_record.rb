class InitiativeRecord < ApplicationRecord
  self.table_name = 'initiatives'

  ALLOWED_STATES = %w[new todo in_progress blocked on_hold done].freeze

  has_many :related_project_relationships,
           class_name: 'InitiativesProjectRecord',
           foreign_key: :initiative_id,
           inverse_of: :initiative,
           dependent: :destroy

  has_many :related_projects, through: :related_project_relationships, source: :project

  validates :name, presence: true, uniqueness: true
  validates :current_state, presence: true, inclusion: { in: ALLOWED_STATES }
end
