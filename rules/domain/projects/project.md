A Project is the central unit of work.

Identifiers and attributes
- `name` is required and globally unique.
- `description` and `point_of_contact` are optional strings defaulting to `''`.
- `archived` defaults to false and is exposed via `archived?`.

Structure and ordering
- A project has a sorted set of child projects loaded lazily via an injected loader.
- Each child project belongs to exactly one parent project at a time.
- Each parent project maintains its own ordering of its child projects; order values are scoped to the parent.
- `leaf?` returns true when the project has no children; false otherwise.
- `leaf_descendants` returns all leaf projects in the subtree (recursively).

State model
- Allowed states: `:new, :todo, :in_progress, :blocked, :on_hold, :done`.
- Only `SetProjectState` mutates state values.
- Leaf projects store `current_state` directly; any state can transition to any other state.
- Parent projects derive `current_state` from their leaf descendants via rollup; stored state is ignored.
- State rollup priority (highest to lowest): `:blocked, :in_progress, :on_hold, :todo, :new, :done`.
  - If any leaf is `:blocked`, parent state is `:blocked`.
  - Else if any leaf is `:in_progress`, parent state is `:in_progress`.
  - Else if any leaf is `:on_hold`, parent state is `:on_hold`.
  - Else if any leaf is `:todo`, parent state is `:todo`.
  - Else if any leaf is `:new`, parent state is `:new`.
  - Else (all leaves `:done`), parent state is `:done`.
- When there are no leaf descendants, state defaults to `:new`.

Health model
- Health enum: `:not_available, :on_track, :at_risk, :off_track`.
- Health updates (value objects) hold `project_id, date, health, description?`; loaded lazily.
- Weekly health updates are a lazily loaded subset for trends.
- Health scoring for rollups: `:on_track => 1`, `:at_risk => 0`, `:off_track => -1`; averages map back via thresholds (>0 `:on_track`, <0 `:off_track`, else `:at_risk`). Subordinate health of `:not_available` is ignored.
- Current health calculation:
  - If subordinate projects exist, health is the rollup average of subordinate current health. Subordinates with `:not_available` health are ignored. If all subordinates have `:not_available` health, health is `:not_available`.
  - If no subordinate projects (leaf), use health updates: `:not_available` when none exist; otherwise the health of the latest update by date.
- Health trend: the last 6 weekly updates plus current health; empty when no updates exist.

Validation
- `valid?` requires present `name` and allowed state; exposes `errors` explaining failures.
