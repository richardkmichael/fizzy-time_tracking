# Fizzy Time Tracking — Database Uninstall Script
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

# Sanity check: verify this is an actual Fizzy database, not an empty file
# created by SQLite because the volume mount path was wrong.
unless connection.table_exists?(:events)
  abort "ERROR: events table not found. Is the storage volume mounted correctly?"
end

# Subquery for time tracking event IDs — kept in the database to avoid
# encoding issues with binary UUID columns in SQLite.
event_subquery = "SELECT id FROM events WHERE eventable_type = 'TimeEntry'"

# Step 1: Delete webhook deliveries for those events.
q = "DELETE FROM webhook_deliveries WHERE event_id IN (#{event_subquery})"
count = connection.delete(q)
puts "Deleted #{count} webhook deliveries"

# Step 2: Delete notifications for those events.
q = "DELETE FROM notifications WHERE source_type = 'Event' AND source_id IN (#{event_subquery})"
count = connection.delete(q)
puts "Deleted #{count} notifications"

# Step 3: Delete the events themselves.
q = "DELETE FROM events WHERE eventable_type = 'TimeEntry'"
count = connection.delete(q)
puts "Deleted #{count} events"

# Step 4: Drop the time_entries table.
if connection.table_exists?(:time_entries)
  connection.drop_table(:time_entries)
  puts "Dropped time_entries table"
else
  puts "time_entries table not present (already removed)"
end

# Step 5: Remove the migration record.
q = "DELETE FROM schema_migrations WHERE version = #{connection.quote(KNOWN_MIGRATION_VERSION)}"
count = connection.delete(q)

if count > 0
  puts "Removed #{count} migration record(s)"
else
  puts <<~WARNING
    WARNING:
      Migration #{KNOWN_MIGRATION_VERSION} not found in schema_migrations.
      The engine migration may have been installed with a different timestamp.
      Multiple image rebuilds can leave multiple orphaned entries.

      List orphaned entries with:

        docker run --rm -e SECRET_KEY_BASE_DUMMY=1 \\
          -v YOUR_VOLUME:/rails/storage \\
          ghcr.io/basecamp/fizzy:main \\
          bin/rails db:migrate:status

      Look for "NO FILE" entries that don't belong to other engines, and
      remove them one at a time (replace THE_VERSION with each version):

        docker run --rm -e SECRET_KEY_BASE_DUMMY=1 \\
          -v YOUR_VOLUME:/rails/storage \\
          ghcr.io/basecamp/fizzy:main \\
          bin/rails runner \\
          "ActiveRecord::Base.connection.execute('DELETE FROM schema_migrations WHERE version = \\'THE_VERSION\\'')"
  WARNING
end

puts "Done."
