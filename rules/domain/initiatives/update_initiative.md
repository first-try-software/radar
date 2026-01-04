Action: UpdateInitiative
- Purpose: replace an existing Initiative in the InitiativeRepository with a new instance.
- Inputs: initiative id; initiative attributes (`name`, optional `description`, optional `point_of_contact`, archived flag).
- Failures: initiative not found; new initiative invalid; new initiative name conflicts with an existing Initiative.
- Success: returns Result.success with the updated Initiative persisted.
