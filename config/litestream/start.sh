# Entry point for the Litestream accessory in config/deploy.yml.
#
# It starts as root only to hand the shared storage volume to the app's user:
# Docker creates the volume root-owned when this accessory boots before the app
# does. Litestream then runs as that user so the SQLite files it creates stay
# writable by Rails.
set -e
chown 1000:1000 /rails/storage
exec setpriv --reuid=1000 --regid=1000 --clear-groups sh -ec '
  # A server without a database, such as a replacement for a dead one, starts
  # from the latest backup.
  litestream restore -if-db-not-exists -if-replica-exists /rails/storage/production.sqlite3
  exec litestream replicate
'
