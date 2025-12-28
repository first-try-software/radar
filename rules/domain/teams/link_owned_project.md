Action: LinkOwnedProject
- Purpose: link an existing top-level Project to a Team's `owned_projects` sorted set (as last).
- Inputs: team id; project id.
- Failures: team not found; project not found; project has a parent (only top-level projects can be owned).
- Success: returns Result.success with the linked Project; persists the team-to-project relationship with order at the end of the set.

