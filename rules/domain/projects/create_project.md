Action: CreateProject
- Purpose: instantiate a new Project and persist it via ProjectRepository.
- Inputs: `name`, optional `description`, optional `point_of_contact`.
- Failures: project invalid; project name conflicts with an existing Project.
- Success: returns Result.success with the created Project persisted.
