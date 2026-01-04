# TODO

## SMALL THINGS
* [x] Use zen logo on home page
* [x] Are Archived projects being inluded in health? NO
* [ ] Sticky header not working
* [ ] Health update hit text highly recommended
* [ ] Spacing beneath search dropdown is too much
* [ ] Archive badge missing until refresh
* [ ] Use gradient on line items based on current status
* [ ] Sticky header state badge is wrong + should be dropdown
* [ ] Incoprorate current health into trend
* [ ] Create project hover state is wrong on search
* [ ] Initiative breadcrumbs still wrong
* [ ] Projects section should match all other pages
* [ ] Improve tab stops everwhere.
* [ ] State should not include New
* [ ] Should archived be a state rather than a boolean?
* [ ] Review opportunities for null objects in NIL.md
* [ ] Review opportunities to remove specs that test constructors in INIT.md

## FEATURE IDEAS
* [ ] Project filters
    * [ ] All
    * [ ] What's going well
    * [ ] What needs leadership attention (at risk / off track / blocked / unowned)
    * [ ] What needs management attention (stale)
* [ ] Executive summary
* [ ] People with contact fields
* [ ] Personal dashboard / check in
* [ ] Authentication
* [ ] Authorization
* [ ] Services with metrics-based health
* [ ] Track incidents related to services, include in service health
* [ ] Objectives / Key Results (stand alone? or related to what entities?)
* [ ] Automated inputs - from metrics, Jira, etc.
* [ ] Stability (stable/mixed/volatile) for services
* [ ] Confidence trend
* [ ] Link and unlink projects
* [ ] Critical projects
    * [ ] 2x weight
    * [ ] Requires comment to enable

## DUMB IDEAS
* [ ] Add randomly rotating taglines
    - If you know, you know. And you come here to share.
    - If you know, you know. If you don't you come here to learn.
    - Eh, what's up, Doc?
    - Know what's up.

## PRODUCT QUESTIONS
* [ ] Should "or create" be removed
* [ ] Should "find or create" allow creation of teams
* [ ] Should "find or create" allow creation of intiatives
* [ ] Should last updates be inherited?

## TECHNICAL QUESTIONS
* [ ] Should CSS be split into multiple files with specific contexts?

## REFACTORS
* [ ] Remove v2 suffix from class names (no v1 exists)
* [ ] Look for duplicate logic, consider refactoring
* [ ] Move logic out of views
* [ ] Move logic out of controllers
* [ ] Move logic out of models
* [ ] Refactor HEALTH_SCORE into a class instead of a hash

## THINGS NOT NEEDING REFACTORING
* [x] archive_project.rb (action)
* [x] create_project_health_update.rb (action)
* [x] create_project.rb (action)
* [x] create_subordinate_project.rb (action)
* [x] find_project.rb (action)
* [x] health_update.rb (entity)
* [x] link_subordinate_project.rb (action)
* [x] project_attributes.rb
* [ ] project_health.rb
* [x] project_hierarchy.rb
* [x] project_loaders.rb
* [ ] project_sorter.rb
* [ ] project_trend_service.rb
* [ ] project.rb
* [x] set_project_state.rb (action)
* [x] unarchive_project.rb (action)
* [x] unlink_subordinate_project.rb (action)
* [x] update_project.rb (action)

---

## What an executive summary might look like

Executive Summary View (one screen)

* Header
    * Period (Q2 2025)
    * Snapshot timestamp

* Section 1: At a glance
    * Overall health
    * Stability (Stable / Mixed / Volatile)
    * Confidence trend (↑ ↓ →)

* Section 2: Notable changes
    * Auto-generated bullets (editable)

* Section 3: Exposure
    * Auto-flagged items with brief rationale

* Section 4: Leadership leverage
    * Empty by default
    * Explicitly authored by you (captured in Status)

* Section 5: What’s changing next
    * Short, explicit commitments


# Project, Inititative, Team health

## Projects

* Array to score = direct children, not all descendants
* Score = average of health scores

## Initiatives

* Array to score = top-level releated projects
* Score = average of health scores
 
## Teams
* Array to score = direct child teams + average of direct owned projects
* Score = average of health scores


# Health & Health Scores

Currently, HealthUpdates store a string. They should record a number. It would save a bunch of conversions.

* HEALTH_SCORES = { on_track: 1, at_risk: 0, off_track: -1 }
* HEALTH_THRESHOLDS = { on_track: 0.5, off_track: -0.5 }

ProjectHealth
InitiativeHealth
TeamHealth
 - All three use HealthScore

HealthScore
 - Calculates scores and returns the appropriate characterizations of the scores