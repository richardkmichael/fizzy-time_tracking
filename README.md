# Fizzy Time Tracking

A Rails engine that adds per-card time tracking to [Fizzy](https://github.com/basecamp/fizzy). Log time, remove time, and view totals directly from the card interface.

## Setup

Clone the repo and run the setup task, which clones Fizzy into `test/fizzy/`, wires in the engine, and prepares the database:

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
cd test/fizzy && bin/dev
```

Or if you used `FIZZY_PATH`, run `bin/dev` from that directory. Changes to engine files (models, views, controllers, CSS) are picked up automatically — no need to copy files or re-run setup.

## Testing

```bash
rake test
```

This runs the engine's test suite (model, controller, integration, and system tests) inside the Fizzy host app. CI also runs the full Fizzy test suite to catch regressions.

## Deployment

The included Dockerfile layers the engine onto the public Fizzy image. Build and push to your container registry:

```bash
docker build -t ghcr.io/richardkmichael/fizzy-time_tracking:latest .
docker push ghcr.io/richardkmichael/fizzy-time_tracking:latest
```

The image is a drop-in replacement for `ghcr.io/basecamp/fizzy:main` with time tracking enabled. Deploy it the same way you deploy Fizzy — just point at the new image and run migrations:

```bash
bin/rails db:migrate
```

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
