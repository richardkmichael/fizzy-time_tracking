# Uninstalling Fizzy Time Tracking

If you've been running the `fizzy-time_tracking` Docker image and want to revert
to the official `basecamp/fizzy` image, you'll need to uninstall the database
artifacts left behind by the engine.

## Why uninstalling is needed

The time tracking engine creates a `time_entries` table and writes records into
several of Fizzy's own tables (events, notifications, webhook deliveries). When
you switch back to the official image, the engine code is gone but the data
remains. Orphaned event records with `eventable_type: "TimeEntry"` will cause
errors when Fizzy tries to load the missing `TimeEntry` class — for example,
when displaying card activity timelines or processing notifications.

## Running the uninstall

If you have the fizzy-time_tracking repo checked out, use the rake task:

```
rake uninstall              # uses default Docker volume
rake uninstall[./data]      # bind-mounted directory
```

Otherwise, run manually. All commands use the official Fizzy image with your
existing storage volume mounted.

1. Download the uninstall script:

   ```
   curl -O https://raw.githubusercontent.com/richardkmichael/fizzy-time_tracking/main/remove_time_tracking.rb
   ```

2. Run it against your database. Replace `YOUR_VOLUME` with your storage volume
   name or bind mount path (the same one you used with the time tracking image):

   ```
   docker run --rm \
     -e SECRET_KEY_BASE_DUMMY=1 \
     -v YOUR_VOLUME:/rails/storage \
     -v $(pwd)/remove_time_tracking.rb:/rails/remove_time_tracking.rb \
     ghcr.io/basecamp/fizzy:main \
     bin/rails runner remove_time_tracking.rb
   ```

3. Start Fizzy normally with the official image.

The script is idempotent — running it multiple times is safe.

## What the script removes

- `webhook_deliveries` tied to time tracking events
- `notifications` tied to time tracking events
- `events` with `eventable_type: "TimeEntry"`
- The `time_entries` table
- The engine's `schema_migrations` record

## What the script leaves behind

- System comments on cards (e.g., "Kevin added 2h 30m") — these are plain text
  with no references back to time tracking models, so they won't cause errors.
  They serve as a historical record of time that was logged.

- Watch records — if a user started watching a card because they logged time on
  it, that watch remains. This is harmless.

## If the migration version doesn't match

The script tries to remove migration version `20260205000001` from
`schema_migrations`. If the engine migration was installed with a different
timestamp (this can happen depending on existing migrations), the script will
print a warning. To find and remove the orphaned entry:

```
docker run --rm \
  -e SECRET_KEY_BASE_DUMMY=1 \
  -v YOUR_VOLUME:/rails/storage \
  ghcr.io/basecamp/fizzy:main \
  bin/rails db:migrate:status
```

Look for a line with `NO FILE` — that's the orphaned migration. Remove it with:

```
docker run --rm \
  -e SECRET_KEY_BASE_DUMMY=1 \
  -v YOUR_VOLUME:/rails/storage \
  ghcr.io/basecamp/fizzy:main \
  bin/rails runner \
  "ActiveRecord::Base.connection.execute(\"DELETE FROM schema_migrations WHERE version = 'THE_VERSION'\")"
```

Replace `THE_VERSION` with the version number shown in the `NO FILE` line.
