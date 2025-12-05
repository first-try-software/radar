Action: CreateInitiative
- Purpose: instantiate a new Initiative and persist it via InitiativeRepository.
- Inputs: `name`, optional `description`, optional `point_of_contact`.
- Failures: initiative invalid; initiative name conflicts with an existing Initiative.
- Success: returns Result.success with the created Initiative persisted.
