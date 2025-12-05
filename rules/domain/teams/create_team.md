Action: CreateTeam
- Purpose: instantiate a new Team and persist it via TeamRepository.
- Inputs: `name`, optional `vision`, optional `mission`, optional `point_of_contact`.
- Failures: team invalid.
- Success: returns Result.success with the created Team persisted.
