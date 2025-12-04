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

A Project has a current_state attribute that must be one of [:todo, :in_progress, :blocked, :on_hold, :done]. The current_state can only be updated through the SetProjectState action. When a Project is intialized, its default state is :new. But that is the only way to reach that state. The state diagram for a project looks like this:

:new -> :todo -> [:blocked, :on_hold, :done]
:blocked -> :todo
:blocked -> :done
:on_hold -> :todo
:on_hold -> :done

:done is the terminal state.