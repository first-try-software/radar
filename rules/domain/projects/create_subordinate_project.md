CreateSubordinateProject is an action that instantiates a new Project and tries to add it to the sorted set entitled "projects" as the last item in the set.

CreateSubordinateProject fails and returns a Result with errors if the new Project is not valid.

CreateSubordinateProject fails and returns a Result with errors if the new Project's name conflicts with any existing Project name. The error message is "team name must be unique".

CreateSubordinateProject succeeds and returns a Result with the newly created Project as the value when it successfully adds the new project to the sorted set AND adds the new Project to the ProjectRepository.
CreateSubordinateProject persists the parent-child relationship with an integer order field representing the position within the parent's sorted set.