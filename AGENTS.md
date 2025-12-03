# Overview

Status is a simple web application for tracking project, team, or intiative.

The central concept of the application is a project. Teams and initiatives are concepts layered atop projects to provide reporting structures.

# Development Philosophy

This project follows these rules:

* Specifications before code.
  * No code is written without a failing spec.
  * Write only enough code to make the spec pass.
  * Specs are written in RSpec.
  * We spec the software incrementally.

* Use hexagonal architecture.
  * Domain logic lives in isolation at the center of the application.
  * Use adapters to isolate domain logic from the outside world.
  * Use repositories to isolate domain logic from databases.
  * Domain logic may not take references to anything outside the domain.
  * Dependencies must be passed in to the domain layer.

* Develop from the inside out.
  * Always specify and build the domain logic first.
  * Add (or specify and build) a web wrapper around the domain logic.
  * Finally, specify and build a user interface for the application.
  * Add or specify and build a web framework.
  * Specify and build a user interface.

* Use service objects called `Actions` for taking actions on entities.
  * These Action objects are named with a verb followed by a noun.
    * The verb represents the action being taken.
    * The noun represents the entity being acted upon.
  * Actions are sent the message `perform` to invoke them.
  * Actions return a Result object with `#success?`, `value`, and `errors`.

* Arrange the domain layer by entities.
  * Include service objects near the entities they act upon.

* Keep specifications simple.
  * Use the arrange, act, assert pattern.
  * Avoid let: Prefer local variables over let statements.
  * Avoid shared specs: Prefer duplication.
  * Avoid shared contexts: Prefer duplication.
  * Avoid nested contexts: Prefer flatter specs with descriptive names.
  * Prefer specs with a single assertion.
  * Assert on no more than five things in a single spec.

* And...
  * Constructors should only set instance variables.
  * Constructors must not run code that can fail.
  * Constructors must not throw exceptions.
  * Do not test constructors.
  * Avoid returning nil from a method: Prefer the null object pattern.
  * Favor objects over primitives.
  * Require 100% test coverage before moving on to the next thing.
  * Require an average method complexity from flog below 10.
  