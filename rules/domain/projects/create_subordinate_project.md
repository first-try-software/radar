Action: CreateSubordinateProject
- Purpose: create a new Project and append it to a parent Project’s children sorted set (as last).
- Inputs: parent project id; project attributes (`name`, optional `description`, optional `point_of_contact`).
- Constraints: the created child is attached to exactly one parent project; ordering is maintained within the parent’s set.
- Failures: project invalid; project name conflicts with any existing Project (error text: `"project name must be unique"`).
- Success: returns Result.success with the created Project; persists the Project and parent-child relationship with order at the end of the parent’s set.
