Action: LinkRelatedProject
- Purpose: link an existing top-level Project to an Initiative's `related_projects` sorted set (as last).
- Inputs: initiative id; project id.
- Failures: initiative not found; project not found; project has a parent (only top-level projects can be related).
- Success: returns Result.success with the linked Project; persists the initiative-to-project relationship with order at the end of the set.

