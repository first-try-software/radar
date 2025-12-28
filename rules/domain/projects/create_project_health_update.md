Action: CreateProjectHealthUpdate
- Purpose: create and persist a HealthUpdate for a leaf Project.
- Inputs: `project_id`, `date`, `health` (`:on_track|:at_risk|:off_track`), optional `description`.
- Failures: project not found; project is not a leaf (has children); missing date; date in the future; health not allowed.
- Success: returns Result.success with the created HealthUpdate after persisting via HealthUpdateRepository and associating to the Project.
- Note: Health updates can only be created for leaf projects (projects without children). Parent projects derive their health from rollups of their children.

