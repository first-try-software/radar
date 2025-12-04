CreateOwnedProject is an action that instantiates a new Project and adds it to a Team's owned_projects set as the last item.

CreateOwnedProject fails and returns a Result with errors if the Team cannot be found.
CreateOwnedProject fails and returns a Result with errors if the new Project is not valid.
CreateOwnedProject fails and returns a Result with errors if the new Project's name conflicts with an existing Project.

CreateOwnedProject succeeds and returns a Result with the newly created Project as the value when it successfully adds the new project to the Team and persists the Team-to-Project relationship with the correct order.

