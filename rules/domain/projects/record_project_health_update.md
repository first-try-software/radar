Action: RecordProjectHealthUpdate
- Purpose: create and persist a HealthUpdate for a Project.
- Inputs: `project_id`, `date`, `health` (`:on_track|:at_risk|:off_track`), optional `description`.
- Failures: project not found; project state not in `[:in_progress, :blocked]`; missing date; health not allowed.
- Success: returns Result.success with the created HealthUpdate after persisting via HealthUpdateRepository and associating to the Project.
