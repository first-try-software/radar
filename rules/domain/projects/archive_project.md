Action: ArchiveProject
- Purpose: mark a Project as archived and persist it via ProjectRepository.
- Inputs: project id.
- Failures: project not found.
- Success: returns Result.success with the archived Project persisted.
