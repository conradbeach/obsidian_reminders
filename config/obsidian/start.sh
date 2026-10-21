# Entry point for the obsidian accessory in config/deploy.yml.
#
# It starts as root only to hand the vault volume to the node user (uid 1000,
# the same as the app's user): Docker creates the volume root-owned. Obsidian
# Headless then installs into and runs from the node user's home volume.
#
# Its sync state lives in the vault volume (/vault/.ob-state, a dot-folder it
# doesn't sync), so the two can only be lost together: state outliving a wiped
# vault would read as every note having been deleted, and two-way sync would
# spread that to every device.
set -e
chown 1000:1000 /vault
exec setpriv --reuid=1000 --regid=1000 --clear-groups env HOME=/home/node XDG_CONFIG_HOME=/vault/.ob-state sh -ec '
  npm install --global --prefix "$HOME/.npm-global" obsidian-headless@0.0.14
  ob="$HOME/.npm-global/bin/ob"

  until "$ob" sync-status --path /vault > /dev/null 2>&1; do
    echo "Waiting for the vault to be set up with bin/kamal ob sync-setup (see README.md)"
    sleep 60
  done

  # A fresh one-shot sync every 30 seconds rather than continuous mode, whose connection can go stale: it kept
  # logging "Fully synced" while missing changes until restarted. Each sync holds the lock the app takes before
  # checking off a reminder in a note (Vault::LOCK_FILE), so the two never touch a note at the same time.
  while true; do
    flock /vault/.reminders.lock "$ob" sync --path /vault || echo "Sync failed; retrying in 30 seconds"
    sleep 30
  done
'
