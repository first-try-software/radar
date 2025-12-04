SetProjectState is an action that updates a Project's current_state.

SetProjectState fails and returns a Result with errors if the Project cannot be found.
SetProjectState fails and returns a Result with errors if the provided state is not one of [:todo, :in_progress, :blocked, :on_hold, :done].

SetProjectState succeeds and returns a Result with the Project when it successfully updates current_state and persists the Project.

