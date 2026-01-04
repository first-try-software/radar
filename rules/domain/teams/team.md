A Team represents a group of people working together.

Identifiers and attributes
- `name` is required and unique among teams.
- `description` and `point_of_contact` are optional strings defaulting to `''`.
- `archived` defaults to false and is exposed via `archived?`.

Structure and ordering
- A team may own projects AND/OR have subordinate teams (not mutually exclusive).
- Teams may only own top-level (parentless) projects; child projects cannot be owned by teams.
- Owns an ordered set of projects (`owned_projects`) loaded lazily; order is persisted as integers within the team scope.
- Manages an ordered set of subordinate teams (`subordinate_teams`) loaded lazily.

Health model
- Uses health rollup scoring (`:on_track => 1`, `:at_risk => 0`, `:off_track => -1`; thresholds >0.5 `:on_track`, <=-0.5 `:off_track`, else `:at_risk`).
- Health uses the following algorithm to calculate health scores:
    - If there are only subordinate teams:
        - The score is the average of each subordinate team's score.
    - If there are only owned projects:
        - The score is the average of each owned project's score.
    - If there are both:
        - The average of owned project scores is treated as a virtual team.
        - Therefore the score is:
            (subordinate_teams.sum(0.0) + average(owned_projects)) / (subordinate_teams.length + 1)
- Only owned projects in active states (`:in_progress`, `:blocked`) contribute to local health.
- Subordinate teams with `:not_available` health are ignored.
- If there are no local projects in active states and no subordinate teams with available health, team health is `:not_available`.

Validation
- `valid?` requires present `name`; exposes `errors` describing failures.
