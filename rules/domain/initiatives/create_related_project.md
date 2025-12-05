Action: CreateRelatedProject
- Purpose: create a new Project and append it to an Initiative’s `related_projects` sorted set (as last).
- Inputs: initiative id; project attributes (`name`, optional `description`, optional `point_of_contact`).
- Failures: initiative not found; project invalid; project name conflicts with an existing Project.
- Success: returns Result.success with the created Project; persists the Project and the initiative-to-project relationship with order at the end of the set.
