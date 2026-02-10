# Fizzy Time Tracking — Database Cleanup Script
#
# Removes all database artifacts left by the fizzy-time_tracking engine.
# Run this after reverting to the official basecamp/fizzy Docker image.
#
# Usage:
#   RAILS_ENV=production bin/rails runner remove_time_tracking.rb
#
# This script is idempotent — safe to run multiple times.
# See UNINSTALLING.md for the full round-trip procedure.

KNOWN_MIGRATION_VERSION = "20260205000001"

connection = ActiveRecord::Base.connection

# Step 1: Find all events created by the time tracking engine.
event_ids = connection.select_values(
  "SELECT id FROM events WHERE eventable_type = 'TimeEntry'"
)

if event_ids.any?
  joined_event_ids = event_ids.map { |id| connection.quote(id) }.join(", ")

  # Step 2: Delete webhook deliveries for those events.
  q = "DELETE FROM webhook_deliveries WHERE event_id IN (#{joined_event_ids})"
  count = connection.delete(q)
  puts "Deleted #{count} webhook deliveries"

  # Step 3: Delete notifications for those events.
  q = "DELETE FROM notifications WHERE source_type = 'Event' AND source_id IN (#{joined_event_ids})"
  count = connection.delete(q)
  puts "Deleted #{count} notifications"

  # Step 4: Delete the events themselves.
  q = "DELETE FROM events WHERE eventable_type = 'TimeEntry'"
  count = connection.delete(q)
  puts "Deleted #{count} events"
else
  puts "No time tracking events found"
end

# Step 5: Drop the time_entries table.
if connection.table_exists?(:time_entries)
  connection.drop_table(:time_entries)
  puts "Dropped time_entries table"
else
  puts "time_entries table not present (already removed)"
end

# Step 6: Clean up the migration record.
q = "DELETE FROM schema_migrations WHERE version = #{connection.quote(KNOWN_MIGRATION_VERSION)}"
count = connection.delete(q)

if count > 0
  puts "Removed migration record #{KNOWN_MIGRATION_VERSION}"
else
  puts <<~WARNING
    WARNING:
      Migration #{KNOWN_MIGRATION_VERSION} not found in schema_migrations.
      The engine migration may have been installed with a different timestamp.

      Check for orphaned entries with:

        RAILS_ENV=production bin/rails db:migrate:status

      Look for a "NO FILE" entry related to create_time_entries and remove it:

        RAILS_ENV=production bin/rails runner "ActiveRecord::Base.connection.execute(\"DELETE FROM schema_migrations WHERE version = 'THE_VERSION'\")"
  WARNING
end

puts "Done."
