CreateRelatedProject is an action that instantiates a new Project and adds it to an Initiative's related_projects set as the last item.

CreateRelatedProject fails and returns a Result with errors if the Initiative cannot be found.
CreateRelatedProject fails and returns a Result with errors if the new Project is not valid.
CreateRelatedProject fails and returns a Result with errors if the new Project's name conflicts with an existing Project.

CreateRelatedProject succeeds and returns a Result with the newly created Project as the value when it successfully adds the new project to the Initiative and persists the Initiative-to-Project relationship with the correct order.

