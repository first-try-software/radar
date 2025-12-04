A Project is the central concept of the application.
A Project represents a unit of work.

A Project has a globally unique name.
A Project may have a description.
A Project may have a point_of_contact.

A Project has a valid? predicate.

--

A Project contains a sorted set of subordinate Projects that may be loaded lazily via a loader object.
Each subordinate Project has a globally unique name.
Each subordinate Project is related to its parent through a relationship that stores an integer order used to sort the set.
Project order is evaluated within the scope of the parent Project's sorted set.

--

A Project has a current_state attribute that must be one of [:new, :todo, :in_progress, :blocked, :on_hold, :done]. 
The current_state can only be updated through the SetProjectState action. 
When a Project is initialized, its default state is :new. But that is the only way to reach that state. 
The state diagram for a project looks like this:

:new -> :todo -> [:blocked, :on_hold, :done]
:blocked -> :todo
:blocked -> :done
:on_hold -> :todo
:on_hold -> :done

:done is the terminal state.

--

Health is an enum of [:not_available, :on_track, :at_risk, :off_track].
HealthUpdate is a value class with project_id, date, health, and optional description.
HealthUpdates may be loaded lazily via a loader in the Project entity.
WeeklyHealthUpdates may also be loaded lazily and represent the subset used for trends.

A project has a current_health that is calculated:
* When a project's current_state is in [:new, :todo, :on_hold, :done]:
  * Its current_health is :not_available.
* When a project's current_state is in [:in_progress, :blocked]:
  * When a project has no health_updates:
    * Its current_health is :not_available.
  * When a project has health_updates:
    * Its current_health is the health of its latest health_update.

A project has a health_trend that is calculated.
* When a project's current_state is in [:new, :todo, :on_hold, :done]:
  * Its health_trend is empty.
* When a project's current_state is in [:in_progress, :blocked]:
  * When a project has no weekly_health_updates:
    * Its health_trend is empty.
  * When a project has weekly_health_updates:
    * Its health_trend is the last 6 weekly_health_updates.
