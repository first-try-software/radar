# Architecture Decisions & Future Directions

This document captures analysis and recommendations for evolving the Radar status application.

---

## 1. Real-Time Updates with Hotwire

### Current State

The application has `turbo-rails` and `stimulus-rails` in the Gemfile, but views use vanilla JavaScript with `fetch()` for AJAX and manual DOM updates.

### What Hotwire Would Provide

- **Turbo Frames**: Instead of reloading the whole page after state changes, health updates, or project creation, just swap the affected frame. The current pattern of `window.location.reload()` after successful operations is the biggest opportunity.
- **Turbo Streams**: When a health update is added, it could automatically broadcast to update the metrics widgets, project lists, and the trend chart across all connected browsers.
- **Stimulus**: Replace inline `<script>` blocks with organized, reusable controllers (state dropdowns, tab switching, modal behavior).

### Recommendation

This would be a significant refactor but very worthwhile. The leaf project update form in `projects/show.html.erb` is the best candidate to convert first—it's self-contained and would benefit most from Turbo Streams for the optimistic update pattern already implemented.

### Documented Decision

I'd like to refactor to Hotwire. I think the user experience will be improved. We should start with `projects/show.html.erb` then move to other pages one at a time with a pause in between for me to confirm the code is of my likeing.

---

## 2. Creating Teams and Initiatives

### Current State

- Root-level projects can be created via the global search "no results" flow
- Subordinate teams can be created from a team's page
- Owned projects can be created from teams
- **No way to create a root-level team or initiative**

### Options

#### Option A: Keep Admin-Only (Recommended)

Update the search placeholder to be honest: "Find teams, initiatives, and projects..." and add a separate admin screen or rake task for creating top-level entities.

#### Option B: Enable in Global Search

When no results found, offer a tabbed create form:
- Create Project (current)
- Create Team (new)
- Create Initiative (new)

### Recommendation

Teams and initiatives are structural scaffolding that shouldn't change often. **Option A is wiser** for most deployments. Most users should be adding projects, not organizational structures. If this is meant to be fully self-service, option B gives flexibility.

### Additional Questions

I wonder if it's easiest to add a + button to team and intiative lists to add one or the other at the current level of abstraction. If we did the same with projects, we'd have consistency across features. Could even add people that way. We could warn of consequences. We could only let certain users see the feature. We could even just wait to see if people abuse it. 

I think I like enabling the feature for certain users. What say you?

---

## 3. Health Update Experience Consistency

### Current Patterns

| Location | Experience |
|----------|------------|
| **Leaf project** (`projects/show.html.erb`) | Inline form with health picker buttons, state dropdown, textarea, AJAX submit with optimistic UI updates |
| **Dashboard** (`dashboard/index.html.erb`) | List views only, no inline update capability |
| **Teams/Initiatives** | Roll-up health from related projects, no direct update (correct, since they're aggregates) |

### Analysis

The leaf project experience is clearly the best. It has:
- Visual health picker (colored buttons)
- Keyboard shortcuts (1/2/3)
- Inline state change
- Toast notifications
- Optimistic UI updates

### Recommendation

Consider a "check-in mode" or "update mode" on the dashboard that lets users quickly update multiple stale projects without navigating to each one. This could be a drawer/panel that opens when clicking a project row, showing the update form inline.

### Additional Questions

I like the idea of a checkin mode. But it would need to be well considered. I do not want a list of every leaf project. Maybe there's a check-in from a project, a team, or an initiative, or even a person, that has all their stuff and only their stuff.

I want to optimize for the entry of health updates. Maybe the home page (beneath search) is the list of things you need to update. The section could disappear whnen not needed.

---

## 4. Person/User Entity

### Current State

`point_of_contact` is a freeform text field on projects, teams, and initiatives. There's `effective_contact` logic that cascades up the hierarchy.

### The Case For a Person Entity

- Consistent formatting (email/Slack handle normalization)
- Linkable profiles
- Assignment to multiple projects
- "What am I responsible for?" view
- Foundation for auth/permissions

### The Case Against (For Now)

- Adds complexity (another CRUD flow, relationships, domain entities)
- The current text field works fine for a read-only dashboard
- Without auth, there's no logged-in user to personalize for

### Recommendation

**Wait until adding auth.** Then the Person/User entity becomes natural—it's the authenticated user. Until then, the contact field serves its purpose. When added, it should probably be called `User` not `Person`, and tie directly to authentication.

---

## 5. Authentication Strategy

### Options

#### Option A: OmniAuth + Database Strategy (Recommended Starting Point)

```ruby
gem 'omniauth'
gem 'omniauth-google-oauth2'  # or provider of choice
gem 'devise'  # optional, for session management
```

- Start with Google OAuth (or just email/password with Devise)
- Add more OmniAuth strategies later (SAML, OIDC, GitHub, etc.)
- The hexagonal architecture makes this clean—add an `AuthenticationService` adapter

#### Option B: Auth0/Clerk/WorkOS

- Zero code for SSO, social login, MFA
- Good for avoiding owning auth entirely
- Can be expensive at scale

#### Option C: Rails 8's Authentication Generator

Rails 8 has `rails generate authentication` that creates a clean, minimal auth system. Great starting point without Devise's complexity.

### Recommended Approach for Hexagonal Architecture

```ruby
# app/services/authentication_adapter.rb
class AuthenticationAdapter
  def authenticate(credentials)
    # Returns a Result with user or errors
  end
end
```

This keeps the domain layer pure (no Rails session concerns) while the adapter handles the OAuth/SSO dance. The `User` entity would live in `lib/domain/users/` following the existing pattern.

### Simplest First Step

Add Google OAuth via OmniAuth. Takes about 30 minutes to set up, provides real users, and the OmniAuth architecture makes adding SAML/OIDC trivial later.

---

## Priority Order

1. **Auth first** — Can't have "my projects" or personalized views without it
2. **Hotwire refactor** — The `window.location.reload()` pattern is the biggest UX debt
3. **Consistent health update experience** — Either a check-in mode or extracting the leaf project form to a reusable partial
4. **Person/User entity** — Falls out naturally from auth
5. **Root team/initiative creation** — Keep as admin-only, just fix the search placeholder copy

---

*Document generated: December 2024*

