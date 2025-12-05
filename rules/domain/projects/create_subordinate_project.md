Action: CreateSubordinateProject
- Purpose: create a new Project and append it to a parent Project’s subordinate_projects sorted set (as last).
- Inputs: parent project id; project attributes (`name`, optional `description`, optional `point_of_contact`).
- Failures: project invalid; project name conflicts with any existing Project (error text: `"team name must be unique"`).
- Success: returns Result.success with the created Project; persists the Project and parent-child relationship with order at the end of the parent’s set.
