# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_14_044130) do
  create_table "health_updates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "description"
    t.string "health", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "date"], name: "index_health_updates_on_project_id_and_date"
    t.index ["project_id"], name: "index_health_updates_on_project_id"
  end

  create_table "initiatives", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "name", null: false
    t.string "point_of_contact", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_initiatives_on_name", unique: true
  end

  create_table "initiatives_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "initiative_id", null: false
    t.integer "order", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id", "order"], name: "index_initiatives_projects_on_initiative_id_and_order", unique: true
    t.index ["initiative_id", "project_id"], name: "index_initiatives_projects_on_initiative_id_and_project_id", unique: true
    t.index ["initiative_id"], name: "index_initiatives_projects_on_initiative_id"
    t.index ["project_id"], name: "index_initiatives_projects_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.string "current_state", default: "new"
    t.text "description", default: "", null: false
    t.string "name", null: false
    t.string "point_of_contact", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_projects_on_name", unique: true
  end

  create_table "projects_projects", force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.integer "order", null: false
    t.integer "parent_id", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_projects_projects_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_projects_projects_on_parent_id_and_child_id", unique: true
    t.index ["parent_id", "order"], name: "index_projects_projects_on_parent_id_and_order", unique: true
    t.index ["parent_id"], name: "index_projects_projects_on_parent_id"
  end

  create_table "teams", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.text "mission", default: "", null: false
    t.string "name", null: false
    t.string "point_of_contact", default: "", null: false
    t.datetime "updated_at", null: false
    t.text "vision", default: "", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  create_table "teams_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order", null: false
    t.integer "project_id", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_teams_projects_on_project_id", unique: true
    t.index ["team_id", "order"], name: "index_teams_projects_on_team_id_and_order", unique: true
    t.index ["team_id", "project_id"], name: "index_teams_projects_on_team_id_and_project_id", unique: true
    t.index ["team_id"], name: "index_teams_projects_on_team_id"
  end

  create_table "teams_teams", force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.integer "order", null: false
    t.integer "parent_id", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_teams_teams_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_teams_teams_on_parent_id_and_child_id", unique: true
    t.index ["parent_id", "order"], name: "index_teams_teams_on_parent_id_and_order", unique: true
    t.index ["parent_id"], name: "index_teams_teams_on_parent_id"
  end

  add_foreign_key "health_updates", "projects"
  add_foreign_key "initiatives_projects", "initiatives"
  add_foreign_key "initiatives_projects", "projects"
  add_foreign_key "projects_projects", "projects", column: "child_id"
  add_foreign_key "projects_projects", "projects", column: "parent_id"
  add_foreign_key "teams_projects", "projects"
  add_foreign_key "teams_projects", "teams"
  add_foreign_key "teams_teams", "teams", column: "child_id"
  add_foreign_key "teams_teams", "teams", column: "parent_id"
end
