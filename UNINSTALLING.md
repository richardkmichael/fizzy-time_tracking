# Uninstalling Fizzy Time Tracking

If you've been running the `fizzy-time_tracking` Docker image and want to revert
to the official `basecamp/fizzy` image, you'll need to clean up the database
artifacts left behind by the engine.

## Why cleanup is needed

The time tracking engine creates a `time_entries` table and writes records into
several of Fizzy's own tables (events, notifications, webhook deliveries). When
you switch back to the official image, the engine code is gone but the data
remains. Orphaned event records with `eventable_type: "TimeEntry"` will cause
errors when Fizzy tries to load the missing `TimeEntry` class — for example,
when displaying card activity timelines or processing notifications.

## Running the cleanup

1. Switch to the official `basecamp/fizzy` image (the same database volume should
   be mounted).

2. Download the cleanup script from this repository:

   ```
   curl -O https://raw.githubusercontent.com/richardkmichael/fizzy-time_tracking/main/remove_time_tracking.rb
   ```

3. Run it:

   ```
   RAILS_ENV=production bin/rails runner remove_time_tracking.rb
   ```

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
RAILS_ENV=production bin/rails db:migrate:status
```

Look for a line with `NO FILE` — that's the orphaned migration. Remove it with:

```
RAILS_ENV=production bin/rails runner \
  "ActiveRecord::Base.connection.execute(\"DELETE FROM schema_migrations WHERE version = 'THE_VERSION'\")"
```

Replace `THE_VERSION` with the version number shown in the `NO FILE` line.
