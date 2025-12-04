RecordProjectHealthUpdate is an action that captures a HealthUpdate for a Project.

RecordProjectHealthUpdate fails and returns a Result with errors if the Project cannot be found.
RecordProjectHealthUpdate fails and returns a Result with errors if the Project's current_state is not in [:in_progress, :blocked].
RecordProjectHealthUpdate fails and returns a Result with errors if the supplied health is not one of [:on_track, :at_risk, :off_track].
RecordProjectHealthUpdate fails and returns a Result with errors if the supplied date is missing.

RecordProjectHealthUpdate succeeds and returns a Result with the created HealthUpdate when it successfully persists the HealthUpdate through the HealthUpdateRepository and associates it with the Project.***

