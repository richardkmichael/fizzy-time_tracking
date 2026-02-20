# Fizzy Time Tracking

Per-card time tracking for [Fizzy](https://github.com/basecamp/fizzy). Log time, remove time, and
view totals directly from the card interface.

This is an application — it produces a deployable Fizzy with time tracking — not a reusable gem. The
engine architecture is just the wiring mechanism for hooking into Fizzy.

## Setup

Clone the repo and run the setup task, which clones Fizzy into `test/fizzy/`, wires in the engine,
and prepares the database:

```bash
git clone https://github.com/richardkmichael/fizzy-time_tracking.git
cd fizzy-time_tracking
rake dev:setup
```

You can point at a specific Fizzy branch or release tag:

```bash
FIZZY_REF=fizzy@37d7f5c rake dev:setup
```

Or use an existing Fizzy checkout instead of cloning:

```bash
FIZZY_PATH=/path/to/fizzy rake dev:setup
```

## Development

After setup, start the Fizzy dev server with the engine loaded:

```bash
rake dev:server
```

Changes to engine files (models, views, controllers, CSS) are picked up automatically — no need to
copy files or re-run setup.

## Testing

```bash
rake test
```

This runs the engine's test suite (model, controller, integration, and system tests) inside the
Fizzy host app. CI also runs the full Fizzy test suite to catch regressions.

## Deployment

### Docker images

CI publishes one Docker image to GHCR:

| Tag | Source | Base Fizzy image | Trigger |
|-----|--------|------------------|---------|
| `latest` | `latest` git tag | Latest Fizzy release | Push of `latest` tag; or every 4h if a new Fizzy release is found |

The `latest` image is the stable deployable build. It is a multi-platform image (linux/amd64 and
linux/arm64), built on native CI runners. It tracks Fizzy releases: whenever Fizzy publishes a
new release, CI automatically detects it, runs tests, and rebuilds the image on the new base. If
tests fail, the existing image is left untouched.

Pushes to `development` run tests only — no image is built or published.

### Keeping up to date with Fizzy

The `latest.yml` workflow runs every 4 hours. It checks the latest
[Fizzy release](https://github.com/basecamp/fizzy/releases) and compares it against what was
last built (cached in GitHub Actions). If a new release is found, it runs the full test suite
against it and, on success, pushes a new `ghcr.io/richardkmichael/fizzy-time_tracking:latest`.

If our tests break on a new Fizzy release, the build fails (and the existing image stays
deployed) until the incompatibility is fixed on `development` and a new `latest` tag is pushed.

### Promoting engine changes to latest

When you have changes on `development` that you want to ship:

```bash
rake release
```

This force-pushes the `latest` git tag to HEAD, immediately triggering `latest.yml`, which runs
tests against the current Fizzy release and pushes a multi-platform image on success. The `latest`
tag always points to the engine code in the `ghcr.io/richardkmichael/fizzy-time_tracking:latest`
image.

### Local builds

To smoke-test the Dockerfile locally (defaults to `ghcr.io/basecamp/fizzy:main` as the base):

```bash
rake dev:build
```

To build against a specific Fizzy release:

```bash
FIZZY_IMAGE_TAG=sha-37d7f5c rake dev:build
```

To run the image locally:

```bash
rake prod:run
```

This uses a Docker named volume for SQLite storage. Pass a path to bind mount a directory instead:

```bash
rake prod:run[./data]
```

The image is a drop-in replacement for `ghcr.io/basecamp/fizzy:main` with time tracking enabled.
Deploy it the same way you [deploy Fizzy](https://github.com/basecamp/fizzy/blob/main/docs/docker-deployment.md).

### Manual CI triggers

Trigger a `latest` rebuild immediately (without waiting for the next scheduled run):

```bash
gh workflow run latest.yml
```

Force a rebuild even if the Fizzy base image hasn't changed:

```bash
gh workflow run latest.yml -f force=true
```

Run tests against a specific Fizzy release instead of `main`:

```bash
gh workflow run development.yml -f fizzy_ref=fizzy@37d7f5c
```

## Reverting to upstream Fizzy

This image modifies your database. If you later switch back to the official `basecamp/fizzy` image,
orphaned records will cause errors on cards where time was logged. Read
[UNINSTALL.md](UNINSTALL.md) before deploying this image so you understand the uninstall
procedure. If you have the repo checked out, `rake uninstall` handles it.

## How it works

The engine:
- Adds a `time_entries` table (UUID primary keys, like all Fizzy tables)
- Includes `Card::Timeable` into the Card model for `has_many :time_entries`
- Prepends routes for `cards/:card_id/time_entries`
- Injects a clock button into the card header and a stylesheet into the layout via an install generator
- Creates timeline events and system comments when time is logged
- Supports both adding and removing time (negative entries for audit trail)

### Database

The engine has one migration (`create_time_entries`) which uses `if_not_exists: true` so it is safe
to re-run. During `docker build`, the install generator copies the migration from the engine into the
host app's `db/migrate/` using Rails' `ActiveRecord::Migration.copy`. On first container start,
`db:prepare` runs the migration against the persistent storage volume.

`Migration.copy` normally assigns a new timestamp based on `Time.now`, which would cause each Docker
rebuild to produce a different migration version number. The install generator uses the `on_copy`
callback to rename the copied file back to its original version (`20260205000001`), ensuring stable
migration versions across rebuilds.

## License

Available under the terms of the [O'Saasy License](LICENSE.md).
