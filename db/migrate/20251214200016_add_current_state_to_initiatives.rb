class AddCurrentStateToInitiatives < ActiveRecord::Migration[8.1]
  def change
    add_column :initiatives, :current_state, :string, default: 'new', null: false
  end
end
