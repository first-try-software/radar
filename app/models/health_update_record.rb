class HealthUpdateRecord < ApplicationRecord
  self.table_name = 'health_updates'

  belongs_to :project, class_name: 'ProjectRecord'

  validates :date, presence: true
  validates :health, presence: true
end
