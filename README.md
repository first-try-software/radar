# Status

Status is a simple web application for gathering project status informaton and reporting that status by project, team, or initiative.

## Entities

The application centers aroud three central concepts: 

* A project is the unit of work the app tracks. 
* Teams provide a hierarchical organizational structure. 
* And, initiatives provide a way to group related projects regardless of ownership.

### Projects

Projects are the most important concept in the application. Users can record project health over time by adding health updates to the project. The latest health update becomes the current health of the project, and a rolling slice of recent weekly updates for the project's health trend.

Each project has a name, description, and point of contact. Projects may be created, found, updated, and arvhived. Projects may contain an ordered list of subordinate projects. Projects also have a state which is goverened by a state machine, as follows:

Projects begin in the `:new` state, move into delivery through `:todo` and `:in_progress`, and can detour to `:blocked` or `:on_hold` before ultimately reaching the terminal `:done` state.

Projects with subordinate projects calculate their current health by averaging the current health of all their subordinate `:in_progress` and `:blocked` projects. Subordinate projects in other states are excluded from the calculation.

### Teams

Teams provide a hierarchical organizing structure for projects. Each team has a name, vision, mission, and point of contact. Teams may be created, found, updated, and archived. And, teams contain subordinate teams as well as an ordered list of owned projects. Creating a project through a team appends it to that team's ordered list, keeping relationships explicit. 

Teams have a current health that is derived from the average of the current health of all their `:in_progress` and `:blocked` projects. Projects in other states are excluded from the calculation.

### Initiatives

Initiatives express higher-level efforts. Like projects, they have a name, description, and point of contact. They may be created, found, updated, and archived. Their defining feature is a sorted set of related projects that captures the work contributing to the initative.

Initiatives have a current health that is derived from the average of the current health of all their `:in_progress` and `:blocked` projects. Projects in other states are excluded from the calculation.

## Actions

All operations flow through explicit Action objects that return Results, keeping domain behavior isolated from infrastructure. Actions create, locate, update, archive, and connect entities. They enforce global name uniqueness, validate the presence of required attributes, and guard state transitions and health updates.

## Architecture

Status is constructed using Hexagonal Architecture and concepts from Domain Driven Design. The domain layer is written in pure Ruby and leverages Specification Driven Development using RSpec. 

### Hexagonal Architecture

Hexagonal Architecture genarally includes three layers: domain, application, and infrastructure.

The domain layer sits at the center of the application containing the most important logic in the app. As sucn, the domain layer, more than any other layer, deserves 100% code coverage. Domain layer objects must never directly reference code outside the domain layer, though they may take references on the interfaces provided by adapters that are injected into the domain layer at object instantiation.

The application layer wraps the domain layer and provides an interface to the outside world. It uses a web or UI framework to accept incoming traffic, and it provides adapters to communicate with external persistence, messaging, and logging systems.

Finally, there's the actual, concrete systems that exist outside the application layer, but remain essential to the operation of the application: web servers, database servers, analytics platforms, and more.

The domain layer is completely custom code. The application layer is glue code. And, the infrastructure layer is mostly configuration as code.

### Specification Driven Development

In Spec Driven Development, the specification is written first, before any code. Developers write down what the software is supposed to do before building the software to gain perspective, come to agreement, and define the boundaries of the problem space. The code, then, becomes the means by which to translate the specifications into something the machines understand.

Specifications act as the first application layer for the code in the domain layer. The specs themselves drive the domain layer, providing fake adapters to the domain layer so that it may exercise its interactions with the outside world.
