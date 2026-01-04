Action: UpdateProject
- Purpose: replace an existing Project in the ProjectRepository with a new instance.
- Inputs: project id; project attributes (`name`, optional `description`, optional `point_of_contact`, optional archived flag).
- Failures: project not found; new project invalid; new project name conflicts with an existing Project.
- Success: returns Result.success with the updated Project persisted.
