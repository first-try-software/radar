Action: CreateOwnedProject
- Purpose: create a new Project and append it to a Team's `owned_projects` sorted set (as last).
- Inputs: team id; project attributes (`name`, optional `description`, optional `point_of_contact`).
- Failures: team not found; project invalid; project name conflicts with an existing Project.
- Success: returns Result.success with the created Project; persists the Project and the team-to-project relationship with order at the end of the set.
- Note: A team may own projects even if it has subordinate teams.
