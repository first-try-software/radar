An Initiative represents a strategic effort composed of projects.

Identifiers and attributes
- `name` is required and unique among initiatives.
- `description` and `point_of_contact` are optional strings defaulting to `''`.
- `archived` defaults to false and is exposed via `archived?`.

Structure and ordering
- Holds an ordered set of related projects loaded lazily; ordering is persisted within the initiative scope.
- Initiatives may only relate to top-level (parentless) projects; child projects cannot be related to initiatives.

Health model
- Uses health rollup scoring (`:on_track => 1`, `:at_risk => 0`, `:off_track => -1`; thresholds >0.5 `:on_track`, <=-0.5 `:off_track`, else `:at_risk`); `:not_available` related project health is ignored.
- Current health is the rollup average of related projects whose `current_state` is `:in_progress` or `:blocked`.
- Related projects in other states are ignored.
- Archived related projects are ignored.
- If no related projects are in an active state, health is `:not_available`.

Validation
- `valid?` requires present `name`; exposes `errors` describing failures.
