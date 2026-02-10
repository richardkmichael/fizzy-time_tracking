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
rake setup
```

You can point at a specific Fizzy branch or SHA:

```bash
FIZZY_REF=stable rake setup
```

Or use an existing Fizzy checkout instead of cloning:

```bash
FIZZY_PATH=/path/to/fizzy rake setup
```

## Development

After setup, start the Fizzy dev server with the engine loaded:

```bash
rake server
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

Build the production Docker image, which layers the engine onto the public Fizzy image:

```bash
rake build
```

To test the image locally:

```bash
rake run
```

This uses a Docker named volume for SQLite storage. Pass a path to bind mount a directory instead:

```bash
rake run[./data]
```

To push to a container registry, tag and push:

```bash
docker tag fizzy-time_tracking ghcr.io/you/fizzy-time_tracking
docker push ghcr.io/you/fizzy-time_tracking
```

The image is a drop-in replacement for `ghcr.io/basecamp/fizzy:main` with time tracking enabled.
Deploy it the same way you [deploy Fizzy](https://github.com/basecamp/fizzy/blob/main/docs/docker-deployment.md).

## Reverting to upstream Fizzy

This image modifies your database. If you later switch back to the official `basecamp/fizzy` image,
orphaned records will cause errors on cards where time was logged. Read
[UNINSTALLING.md](UNINSTALLING.md) before deploying this image so you understand the cleanup
procedure.

## How it works

The engine:
- Adds a `time_entries` table (UUID primary keys, like all Fizzy tables)
- Includes `Card::Timeable` into the Card model for `has_many :time_entries`
- Prepends routes for `cards/:card_id/time_entries`
- Injects a clock button into the card header and a stylesheet into the layout via an install generator
- Creates timeline events and system comments when time is logged
- Supports both adding and removing time (negative entries for audit trail)

## License

Available under the terms of the [O'Saasy License](LICENSE.md).
