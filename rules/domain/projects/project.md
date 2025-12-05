A Project is the central unit of work.

Identifiers and attributes
- `name` is required and globally unique.
- `description` and `point_of_contact` are optional strings defaulting to `''`.
- `archived` defaults to false and is exposed via `archived?`.

Structure and ordering
- A project has a sorted set of subordinate projects loaded lazily via an injected loader.
- Ordering is persisted via an integer order within the scope of the parent project’s set.

State machine
- Allowed states: `:new, :todo, :in_progress, :blocked, :on_hold, :done`.
- Only `SetProjectState` mutates `current_state`.
- Initialization defaults to `:new` (the only way to reach it).
- Transitions:
  - `:new -> :todo`
  - `:todo -> :in_progress | :blocked | :on_hold | :done`
  - `:blocked -> :todo | :done`
  - `:on_hold -> :todo | :done`
  - `:done` is terminal.

Health model
- Health enum: `:not_available, :on_track, :at_risk, :off_track`.
- Health updates (value objects) hold `project_id, date, health, description?`; loaded lazily.
- Weekly health updates are a lazily loaded subset for trends.
- Health scoring for rollups: `:on_track => 1`, `:at_risk => 0`, `:off_track => -1`; averages map back via thresholds (>0 `:on_track`, <0 `:off_track`, else `:at_risk`). Subordinate health of `:not_available` is ignored.
- Current health calculation:
  - If `current_state` in `[:new, :todo, :on_hold, :done]`, health is `:not_available`.
  - If `current_state` in `[:in_progress, :blocked]`:
    - If subordinate projects exist, health is the rollup average of subordinate current health for subordinates whose `current_state` is `:in_progress` or `:blocked`. Subordinates in other states are ignored. If no such subordinates, health is `:not_available`.
    - If no subordinate projects, use health updates: `:not_available` when none exist; otherwise the health of the latest update by date.
- Health trend: empty unless `current_state` in `[:in_progress, :blocked]` **and** weekly updates exist; then the last 6 weekly updates in order.

Validation
- `valid?` requires present `name` and allowed state; exposes `errors` explaining failures.
