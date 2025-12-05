Action: SetProjectState
- Purpose: update a Project’s `current_state` following allowed transitions.
- Inputs: project id; target state (must be one of `[:todo, :in_progress, :blocked, :on_hold, :done]`).
- Failures: project not found; state invalid for the enum; state transition not allowed from current_state.
- Success: returns Result.success with the Project after persisting the new state.
