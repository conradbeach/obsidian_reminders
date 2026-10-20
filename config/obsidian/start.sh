# Entry point for the obsidian accessory in config/deploy.yml.
#
# It starts as root only to hand the vault volume to the node user (uid 1000,
# the same as the app's user): Docker creates the volume root-owned. Obsidian
# Headless then installs into and runs from the node user's home volume.
set -e
chown 1000:1000 /vault
exec setpriv --reuid=1000 --regid=1000 --clear-groups env HOME=/home/node sh -ec '
  npm install --global --prefix "$HOME/.npm-global" obsidian-headless@0.0.14
  ob="$HOME/.npm-global/bin/ob"

  until "$ob" sync-status --path /vault > /dev/null 2>&1; do
    echo "Waiting for the vault to be set up with bin/kamal ob sync-setup (see README.md)"
    sleep 60
  done

  # A fresh one-shot sync every 30 seconds rather than continuous mode, whose connection can go stale: it kept
  # logging "Fully synced" while missing changes until restarted.
  while true; do
    "$ob" sync --path /vault || echo "Sync failed; retrying in 30 seconds"
    sleep 30
  done
'
