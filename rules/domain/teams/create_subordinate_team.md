Action: CreateSubordinateTeam
- Purpose: create a new Team and append it to a parent Team’s `subordinate_teams` sorted set (as last).
- Inputs: parent team id; team attributes (`name`, optional `vision`, optional `mission`, optional `point_of_contact`).
- Failures: parent team not found; team invalid; team name conflicts with an existing Team.
- Success: returns Result.success with the created Team; persists the Team and parent-child relationship with order at the end of the set.
