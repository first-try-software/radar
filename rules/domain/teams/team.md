A Team represents a group of people working together.

A Team has a name.
A Team may have a vision.
A Team may have a mission.
A Team may have a point_of_contact.
A Team tracks whether it has been archived.
A Team owns a sorted set of Projects called owned_projects.
A Team manages a sorted set of subordinate Teams called subordinate_teams.

A Team is valid when it has a non-empty name.
A Team provides a `valid?` predicate and an `errors` collection describing validation failures.

