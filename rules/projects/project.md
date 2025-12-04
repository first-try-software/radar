A Project is the central concept of the application.
A Project represents a unit of work.

A Project has a globally unique name.
A Project may have a description.
A Project may have a point_of_contact.

A Project has a valid? predicate.

A Project contains a sorted set of subordinate Projects.
Each subordinate Project has a globally unique name.
Each subordinate Project is related to its parent through a relationship that stores an integer order used to sort the set.
Project order is evaluated within the scope of the parent Project's sorted set.
