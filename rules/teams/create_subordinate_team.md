CreateSubordinateTeam is an action that instantiates a new Team and adds it to a parent Team's subordinate_teams set as the last item.

CreateSubordinateTeam fails and returns a Result with errors if the parent Team cannot be found.
CreateSubordinateTeam fails and returns a Result with errors if the new Team is not valid.
CreateSubordinateTeam fails and returns a Result with errors if the new Team's name conflicts with an existing Team.

CreateSubordinateTeam succeeds and returns a Result with the newly created Team as the value when it successfully adds the team to the parent Team and persists the parent-child relationship with the correct order.

