A Team represents a group of people working together.

Identifiers and attributes
- `name` is required and globally unique.
- `vision`, `mission`, and `point_of_contact` are optional strings defaulting to `''`.
- `archived` defaults to false and is exposed via `archived?`.

Structure and ordering
- Owns an ordered set of projects (`owned_projects`) loaded lazily; order is persisted as integers within the team scope.
- Manages an ordered set of subordinate teams (`subordinate_teams`) loaded lazily.

Health model
- Uses health rollup scoring (`:on_track => 1`, `:at_risk => 0`, `:off_track => -1`; thresholds >0 `:on_track`, <0 `:off_track`, else `:at_risk`); `:not_available` owned project health is ignored.
- Current health is the rollup average of owned projects whose `current_state` is `:in_progress` or `:blocked`.
- Owned projects in other states are ignored.
- If no owned projects are in a working state, health is `:not_available`.

Validation
- `valid?` requires present `name`; exposes `errors` describing failures.
