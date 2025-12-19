Action: UpdateTeam
- Purpose: replace an existing Team in the TeamRepository with a new instance.
- Inputs: team id; team attributes (`name`, optional `description`, optional `point_of_contact`, archived flag, loaders as needed).
- Failures: team not found; new team invalid.
- Success: returns Result.success with the updated Team persisted.
