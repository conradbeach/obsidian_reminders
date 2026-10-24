# Compares the backup bin/check-backup restored with the live database, then deletes it. Fails if the backup is
# damaged or more than a few minutes behind.
require "sqlite3"

MAX_LAG = 5.minutes
path = Rails.root.join("storage/backup-check.sqlite3")

begin
  restored = SQLite3::Database.new(path.to_s, readonly: true)
  live = ActiveRecord::Base.connection

  integrity = restored.get_first_value("PRAGMA integrity_check")
  puts "Integrity: #{integrity}"

  ["users", "reminders", "push_subscriptions", "sessions"].each do |table|
    count = "SELECT COUNT(*) FROM #{table}"
    puts "#{table}: #{restored.get_first_value(count)} backed up, #{live.select_value(count)} live"
  end

  # Stored in UTC.
  latest = "SELECT MAX(updated_at) FROM reminders"
  backed_up, current = [restored.get_first_value(latest), live.select_value(latest)]
    .map { Time.find_zone("UTC").parse(it.to_s)&.in_time_zone }
  lag = current && backed_up ? current - backed_up : 0
  puts "Latest reminder change: #{backed_up || 'none'} backed up, #{current || 'none'} live"

  abort "Backup check failed" unless integrity == "ok" && lag <= MAX_LAG
  puts "Backup check passed"
ensure
  restored&.close
  Dir["#{path}*"].each { File.delete(it) }
end
