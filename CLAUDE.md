# Fizzy Time Tracking Engine

Standalone Rails engine that adds time tracking to Fizzy.

## Repository Layout

- `app/` — Engine code (models, views, controllers, assets)
- `lib/` — Engine boot, generators, test helpers
- `test/fizzy/` — Host app (full Fizzy clone, set up by `rake setup`)
- `test/fizzy/app/` — Host app files; install generator injects into these

## Development

```bash
rake setup                  # Clone Fizzy host app, install engine, prepare DB
cd test/fizzy && bin/dev    # Start dev server (localhost:3006)
```

Dev URL: http://fizzy.localhost:3006
Landing page: `/{account_id}/` (routes to `events#index`)
Card URL: `/{account_id}/cards/{card_number}`
Login: use any @example.com address (passwordless magic link, check rails console)

After changing the install/uninstall generators, re-run from test/fizzy:
```bash
bin/rails generate fizzy_time_tracking:install
```

### Development Gotchas

- Restart dev server after running migrations (in-memory column cache goes stale)
- Let the user handle dev server lifecycle (don't kill/restart via bash)
- After migrations, restore SQLite schema dumps: `git checkout -- db/cable_schema.rb db/schema_sqlite.rb` (newer SQLite versions add spurious `limit: 255` to string columns)
- `content_for` is a view helper only — cannot be used in controllers or engine initializers; stylesheet injection must go through the install generator
- Use `BUNDLE_GEMFILE=Gemfile.time bundle install` for the time tracking bundle (`eval_gemfile` does NOT inherit version pins from the parent lockfile)

## File Editing Rules

- Engine code (models, controllers, engine views): edit in `app/`
- Host app views that need modification: edit in `test/fizzy/app/`
- When adding a new host file touchpoint, add it to both the install AND uninstall generators
- After adding new generator steps, re-run the generator in `test/fizzy/`

## Host File Touchpoints

The install generator (`lib/generators/fizzy_time_tracking/install_generator.rb`) injects into:
- `app/views/cards/_container.html.erb` — time tracking button (published cards)
- `app/views/cards/drafts/_container.html.erb` — time tracking button (draft cards)
- `app/views/layouts/shared/_head.html.erb` — engine stylesheet

These are the only unavoidable host modifications — there is no engine mechanism to inject into host layouts automatically.

## Engine Wiring (automatic via engine.rb)

Ruby wiring uses `config.to_prepare` (runs at boot, no manual step):
- `Card.include Card::Timeable`
- `Card::Eventable::SystemCommenter.prepend ...::TimeTracking`
- `Event::Description.prepend Event::Description::TimeTracking`
- `User::DayTimeline::TIMELINEABLE_ACTIONS << "time_entry_created"`
- `Webhook::PERMITTED_ACTIONS` extended with `"time_entry_created"`
- Routes: nested `time_entries` under `cards`, `resolve "TimeEntry"` for polymorphic URLs
- Frozen constants (Webhook::PERMITTED_ACTIONS): use `remove_const`/`const_set`
- Unfrozen constants (TIMELINEABLE_ACTIONS): safe to `<<` append

## Adding a New Eventable Type

When adding a model that generates events (like TimeEntry), you need:
1. Eventable partial: `app/views/events/event/eventable/_<model>.html.erb`
2. `resolve "<Model>"` route in engine.rb (for `polymorphic_path` in event links)
3. `Event::Description` prepend module (so `#card` and `#action_sentence` handle the new action)
4. Add action to `TIMELINEABLE_ACTIONS` and `Webhook::PERMITTED_ACTIONS`

## Propshaft Asset Pipeline

- CSS `url()` rewriting resolves relative to `logical_path.dirname`. Engine CSS at `fizzy/time_tracking.css` means `url("clock.svg")` resolves to `fizzy/clock.svg`
- Place engine SVG images at `app/assets/images/fizzy/` to match
- Engine asset paths need separate registration in engine.rb: `app.config.assets.paths << root.join("app/assets/images")`
- Restart dev server after adding new engine asset paths

## UI Patterns (Fizzy Conventions)

- Popup dialog: `<dialog>` + Stimulus `dialog` controller, lazy `turbo_frame_tag` inside. After submission, turbo stream replaces the container div (resets the lazy frame)
- Popup button style: `btn popup__btn` (transparent, rounded). NOT `btn--reversed` (black/pill)
- Icons: custom SVG set in `app/assets/images/`, referenced via `icon_tag "name"`, registered in `app/assets/stylesheets/icons.css` with `.icon--name { --svg: url("name.svg"); }`
- System comments: `SystemCommenter` prepend pattern, renders as `.comment-by-system` (striped background, centered, no avatar)
- Timeline items: 2 lines — line 1 = name + timestamp, line 2 = action content
- CSS colors: oklch system with variables like `--lch-blue-lightest`, `--lch-red-dark`

## Controller Patterns

- No empty method definitions needed (ActionController responds to routes without explicit `def new; end`)
- Use `params.expect(model: [...])` not `params.require(:model).permit(...)`
- For validation errors: `build` + `save!` with `rescue ActiveRecord::RecordInvalid` to re-render the form with 422, rather than `create!` (which raises through middleware)

## Testing

- `sign_in_as :kevin` for controller tests (kevin is admin, has access to logo card)
- `sessions(:david)` for Current.session in model tests
- Fixtures use `ActiveRecord::FixtureSet.identify("name", :uuid)` for deterministic UUIDs
- Reference other fixtures with `_uuid` suffix (e.g., `card: logo_uuid`)
- Fixtures: prepend `ActiveRecord::TestFixtures.singleton_class` for engine fixtures
- System tests: `sign_in_as` uses `visit session_transfer_url(user.identity.transfer_id, script_name: nil)`
- Feature flag in test environment: `touch tmp/time_tracking.txt`
- `RequestForgeryProtectionTest` is a pre-existing flaky test in the host app (Board count mismatch) — ignore it
- System tests with parallel: use `PARALLEL_WORKERS=1` if timing-related flakiness occurs

## Gem Naming

- Gem name: `fizzy-time_tracking` (hyphen-underscore), giving `require "fizzy/time_tracking"` and `Fizzy::TimeTracking` namespace
- All-hyphen (`fizzy-time-tracking`) would produce 3-level `require "fizzy/time/tracking"` (wrong)

## Docker

- Layers on Fizzy's published image (`ghcr.io/basecamp/fizzy:main`)
- `BUNDLE_DEPLOYMENT=""` temporarily lifts strict deployment mode for `bundle add`
- `--conservative` flag ensures existing Fizzy dependencies stay at locked versions
- `db:prepare` in the entrypoint handles engine migrations at boot
- Requires cloning the full repo (not just downloading the Dockerfile)
- Image tag uses underscore: `fizzy-time_tracking`

## CI Architecture

Three workflow files in `.github/workflows/`:

- `ci.yml` — Reusable workflow (`workflow_call`). Runs tests and optionally builds/pushes a Docker image. All test and build logic lives here.
- `development.yml` — Caller workflow. Triggers on push/PR to `development`. Resolves the latest Fizzy Docker image tag, then calls `ci.yml` with `image_tag: development`.
- `latest.yml` — Caller workflow. Runs on a 4-hour schedule. Polls GHCR for new Fizzy Docker images, skips if already built (cache-based), then calls `ci.yml` with `engine_ref: latest` and `image_tag: latest`.

Two environment variables control Fizzy references:

- `FIZZY_REF` — Git ref for `rake setup` (clones Fizzy for testing). Examples: `main`, `fizzy@37d7f5c`
- `FIZZY_IMAGE_TAG` — Docker tag for the `FROM` line in the Dockerfile. Examples: `main`, `sha-37d7f5c`

Tag format mapping: Fizzy release tags (`fizzy@37d7f5c`) correspond to Docker image tags (`sha-37d7f5c`). Not every Fizzy release gets a Docker image — the workflows check GHCR for `sha-*` tags, not GitHub releases.

The `latest` git tag promotes engine code to the stable image. Push with: `git tag -f latest HEAD && git push origin latest --force`

The `latest.yml` skip logic uses GitHub Actions cache (`latest-fizzy-built-{tag}`) to avoid rebuilding when the Fizzy base image hasn't changed. Cache expires after 7 days (GitHub default).

## Rakefile

- Switches `BUNDLE_GEMFILE` to Fizzy's Gemfile before `bundler/setup` for in-process test execution
- Use `sh` for external commands (git, bundle install), NOT for invoking Ruby tools like `rails test`
- `in_fizzy` helper wraps `Bundler.with_unbundled_env` + `Dir.chdir(FIZZY_PATH)`

## Git History Preferences

- Scaffold-first: commit pure `rails plugin new` output, then customize in subsequent commits
- `git commit --fixup=<SHA>` + `git rebase --autosquash` for post-review fixes
- Squash cleanup migrations into the original create migration before shipping
- Commit messages: explain the final state, not the journey of implementation decisions
- Review `git log -p` of the entire repo before publishing

## Style

These files exist after `rake setup` (they live in the Fizzy host app clone):

@test/fizzy/STYLE.md
@test/fizzy/AGENTS.md

## Documentation References

- Rails Guides: https://guides.rubyonrails.org
- Rails API: https://api.rubyonrails.org
- Turbo Handbook: https://turbo.hotwired.dev/handbook/introduction
- Turbo Reference: https://turbo.hotwired.dev/reference/drive
