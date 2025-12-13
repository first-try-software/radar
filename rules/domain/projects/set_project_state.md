Action: SetProjectState
- Purpose: update the `current_state` of a project and its leaf descendants.
- Inputs: project id; target state (must be one of `[:todo, :in_progress, :blocked, :on_hold, :done]`).
- Behavior:
  - Find all leaf descendants of the project (if the project is a leaf, it is its own leaf descendant).
  - Set `current_state` to the target state on all leaf descendants.
  - Persist all updated leaf projects.
- Failures: project not found; state invalid for the enum; state is `:new` (not a valid target).
- Success: returns Result.success with the project (whose derived state reflects the update).
- Note: `:new` is the initial state only; once a project leaves `:new`, it cannot return to it.
