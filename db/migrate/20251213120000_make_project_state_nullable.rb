class MakeProjectStateNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :projects, :current_state, true
  end
end
