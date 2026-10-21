# Obsidian Reminders

Sends push notifications for reminders written in Obsidian notes. The notes stay
in Obsidian, organized however she likes; this app only reads them.

## Writing reminders

Put `(@` + a time + `)` anywhere in a note:

```markdown
- [ ] Call the dentist (@tomorrow 9am)
- [ ] Renew the car registration (@Nov 1)
Water the plants (@friday 6pm)
```

- Times are parsed by `Reminder::Directive`, which understands:
  - dates: `today`, `tomorrow`, weekdays (`friday`, `fri`, `next friday`),
    `Oct 21`, `October 21st 2027`, `21 Oct`, `10/21`, `10/21/26`, `2026-10-21`
  - times: `9am`, `9:30 p.m.`, `21:00`, `noon`, before or after the date, with
    or without `at` (`tomorrow at 9am`, `3pm friday`)
  - durations: `in 30 minutes`, `in an hour`, `in 3 days`, `in two weeks at 10am`

  Everything is Mountain time. A date with no time goes off at 9am. A time with
  no date is the next one, so `9am` written in the evening means tomorrow
  morning; a weekday whose time has already passed today means next week.
  Anything else (`next week`, a bare `9`) isn't guessed at: it shows up under
  **Needs a clearer time**.
- Repeating reminders start with `every`:
  - intervals: `(@every 3 days)`, `(@every day at 8am)`, `(@every other week)`,
    `(@every 6 months)`, `(@every 2 years)`
  - weekdays: `(@every weekday at 7:30am)`, `(@every monday and thursday at 7pm)`,
    `(@every 2 weeks on tuesday at 7:50am)`
  - dates: `(@every year on october 1)`, `(@every april 19)`,
    `(@every month on the 15th)`, `(@every 2nd tue)`,
    `(@every last saturday in october)`, `(@every 3rd sat of sep)`

  Adding `from <date>` (`(@every 6 months from 2027-03-01)`) makes that date the
  first occurrence; otherwise it's the next one that hasn't passed. A repeating
  reminder notifies once per occurrence and stays (eventually Overdue)
  until it's marked done in the app, which moves it to its next occurrence:
  intervals count from the day it was done; everything else moves to its next
  scheduled date. Checking its line off in Obsidian, or removing it, ends it for
  good.
- Relative times are measured from when the app first sees the reminder, about
  a minute after the note syncs. Once seen, a reminder keeps its time even if the
  words would mean something else later ("tomorrow" stays that tomorrow).
- Reminders belong to whoever's folders contain the note. Each user lists their
  folders in **Settings** (say, `Tabitha`), and sees and is notified about
  reminders in notes anywhere inside them. A folder you both list is shared;
  reminders in notes outside everyone's folders are ignored.
- Each reminder notifies each of its users' subscribed devices once. Tapping the notification
  opens the app, where the note's name opens it in Obsidian at the heading the
  reminder is under (Obsidian links can't point to a line).
- Checked-off tasks (`- [x]`) don't notify.
- Reminders can be added in the app too, once a user picks a note for them in
  **Settings** (in one of their folders). "Call the dentist" and "tomorrow 9am"
  become `- [ ] Call the dentist (@tomorrow 9am)` at the end of that note, which
  is created if need be.
- Lines indented under a reminder's line are its notes. The app shows a notes
  icon on reminders that have them; tapping the reminder opens them. Editing
  notes doesn't change the reminder's time.
- Editing anything on a reminder's line, even a typo, makes it a new reminder
  whose time is read again at that moment. A relative directive has to be
  updated along with the edit: fixing a typo tomorrow in a `(@tomorrow)`
  reminder means changing it to `(@today)` too. Absolute dates (`Oct 21 3pm`)
  are unaffected unless the date has passed.
- A reminder whose time has passed stays listed on its day (dimmed, under
  **Yesterday** if need be) until it's been past for each user's overdue hours
  (24 by default, set in **Settings**). Then it moves to **Overdue**, where it
  stays, however old, until it's checked off or removed from the note.
- Tapping the circle beside a one-time reminder marks it done: it disappears from the
  app at once, and the app checks it off in the note (`- [x]`, adding a
  checkbox if the line had none), which reaches her other devices within about
  a minute. Obsidian Sync's version history can undo it.

## How it works

- **Obsidian Headless** ([`ob`](https://obsidian.md/help/sync/headless)) runs as
  a Kamal accessory and keeps a copy of the vault in two-way sync with Obsidian
  Sync, running a one-shot `ob sync` every 30 seconds (its continuous mode
  silently stopped receiving changes). Its sync state lives in the vault volume
  (`/vault/.ob-state`), so the two can't be lost separately: state outliving a
  wiped vault would look like every note being deleted.
- The only change the app makes to notes is checking off a reminder's line
  (`CheckOffReminderJob`, `Vault#check_off`). It edits only a line that appears
  exactly once, unchanged since the last scan; replaces the note in one step;
  and holds a lock (`/vault/.reminders.lock`) that each sync also holds, so it
  never edits a note mid-sync. If the lock is busy it retries.
- `CheckRemindersJob` runs every minute (Solid Queue recurring task). It scans
  every Markdown file in the vault for directives (`Vault`), stores new ones as
  `Reminder`s and deletes ones that are gone (`Reminder.sync`), then sends push
  notifications for reminders that have come due (`Reminder.notify_due`).
  Reminders aren't assigned to users when stored: `User#reminders` matches note
  paths against the user's folders whenever it's asked, so changing folders
  takes effect immediately.
- A reminder that disappears from the vault is hidden at once but only deleted
  after five minutes, so one that briefly vanishes (a scan reading a note while
  Obsidian Headless rewrites it) comes back with its original time and isn't
  sent twice. Obsidian Sync's "(Conflicted copy)" notes are skipped.
- A notification that no device accepts is retried every minute for an hour. A
  reminder whose time is more than an hour past when the app first sees it is
  never sent, so editing an old note or unchecking an old task doesn't notify.
- Background jobs (Solid Queue) are visible in Mission Control at `/jobs`.

## Development

```sh
bin/setup                 # installs gems, prepares the database, starts the server
npm install               # Playwright, for system specs
npx playwright install chromium
```

Create a user in `bin/rails console`:

```ruby
User.create!(email_address: "me@example.com", password: "a long password", note_folders: ["Conrad"])
```

Reminders are read from `tmp/vault` unless `VAULT_PATH` points elsewhere. Put
some notes there and run `CheckRemindersJob.perform_now` in the console to load
them; the recurring job only runs in production.

### Checks

`bin/ci` runs RuboCop, bundler-audit, importmap audit, Brakeman, and RSpec
(model, request, job, and Playwright system specs). GitHub Actions runs the same
checks.

### Keeping dependencies up to date

Nothing updates dependencies automatically, and CI's security audit only runs
on push. Every month or so, update everything, check, and deploy:

```sh
bundle update
bin/importmap outdated   # pin any updates with bin/importmap pin <package>
bin/ci
bin/kamal deploy
```

Also bump the accessory versions now and then, reading their release notes
first: the Litestream, Tailscale, and Node images in `config/deploy.yml` and
`obsidian-headless` in `config/obsidian/start.sh`. Then run
`bin/kamal accessory reboot <name>`.

## Credentials

Settings that shouldn't be in this public repository live in Rails credentials
(`bin/rails credentials:edit`):

```yaml
vapid:            # push notification keys; changing them breaks every phone's subscription
  subject: https://reminders.example.ts.net
  public_key: ...
  private_key: ...
deploy:
  server: home-server                      # SSH host for Kamal
  ssh_user: conrad
  host: reminders.example.ts.net           # the app's Tailscale HTTPS name; its first part names the Tailscale node
obsidian:
  vault_name: My Vault                     # the vault's name in Obsidian, for links that open a note
tailscale:
  auth_key: tskey-auth-...                 # only needed the first time the tailscale accessory boots
litestream:       # Cloudflare R2 backups; optional until set up (see Backups)
  endpoint: https://<account id>.r2.cloudflarestorage.com
  bucket: obsidian-reminders
  access_key_id: ...
  secret_access_key: ...
```

Kamal reads them through `.kamal/credentials.rb` when it renders
`config/deploy.yml`, `.kamal/secrets`, and the Litestream config, without
booting Rails.

## Deployment

The app deploys with [Kamal](https://kamal-deploy.org) to the home server, which
is only reachable over Tailscale:

- The `tailscale` accessory is a Tailscale node of its own (named after the
  first part of `deploy.host`) that provides HTTPS with a `*.ts.net`
  certificate and forwards to kamal-proxy. HTTPS is required for installing the
  PWA and for push notifications, and a separate name keeps the app's cookies
  and service worker apart from other apps on the server.
- kamal-proxy listens on `127.0.0.1:8380` and routes by host name. It's shared
  by every Kamal app on the server; keep their proxy settings in sync.
- Kamal runs a local registry and tunnels it over SSH, so no Docker Hub account
  is needed.

### First deploy

1. In the Tailscale admin console, make sure HTTPS certificates are enabled
   (DNS → HTTPS Certificates), then create an auth key (Settings → Keys →
   Generate auth key; one-off is fine) and put it in the `tailscale` credentials.
2. Deploy and create a user:
   ```sh
   bin/kamal setup
   bin/kamal console   # User.create!(email_address: ..., password: ...)
   ```
3. In the admin console's Machines list, open the new `reminders` machine and
   **Disable key expiry**, so it doesn't drop off the tailnet in six months.
4. Connect the vault. Obsidian Headless needs an Obsidian Sync subscription and
   her Obsidian account; if the vault is end-to-end encrypted, `sync-setup`
   also asks for its encryption password.
   ```sh
   bin/kamal ob login
   bin/kamal ob sync-list-remote
   bin/kamal ob 'sync-setup --vault "My Vault" --path /vault --device-name "Reminders server"'
   bin/kamal accessory logs obsidian   # should show the first sync within a minute
   ```
   Sync is two-way, the default, so reminders checked off in the app reach her
   notes. Obsidian's settings aren't synced by default. Attachments (images, audio,
   PDFs, video) are, and Obsidian Headless has no way to turn them all off: an
   empty `--file-types` resets it to that default. Quote everything after `ob`
   so Kamal passes the options through.

After that, `bin/kamal deploy` deploys new versions.

### Notifications on iPhone

iOS only allows push notifications for web apps added to the Home Screen
(iOS 16.4 or later):

1. Open the app's `https://reminders.<tailnet>.ts.net` URL in Safari and sign in.
2. Share → **Add to Home Screen**.
3. Open Reminders from the Home Screen and tap **Turn on** in the notifications
   banner. The banner only appears while notifications aren't working; they can
   be turned off for a device in **Settings**.

Each phone subscribes separately.

## Backups

[Litestream](https://litestream.io) runs as a Kamal accessory next to the app
and continuously copies changes to `storage/production.sqlite3` to the
`obsidian-reminders` bucket in Cloudflare R2. It takes a full snapshot daily and
keeps 30 days of history (`config/litestream/litestream.yml.erb`). The cache,
queue, and cable databases aren't backed up because their data is disposable.

The database is small and mostly rebuildable: reminders come from the vault, so
what a backup really saves is users, push subscriptions, and which reminders
have already been sent. The vault itself is backed up by Obsidian Sync.

### Setup

1. In the Cloudflare dashboard, open R2 Object Storage and create a bucket named
   `obsidian-reminders` (Standard storage class; the free tier doesn't cover
   Infrequent Access).
2. Under R2 → **Manage API tokens**, create an Account API token with **Object
   Read & Write** permission for that bucket only and no expiration.
3. Add its access key ID and secret access key to the `litestream` credentials.
4. `bin/kamal accessory boot litestream` (or `bin/kamal setup` on a new
   server), then check `bin/kamal accessory logs litestream` for errors.

### Restoring onto a new server

The Litestream accessory restores the latest backup whenever the server has no
database (`config/litestream/start.sh`). On the replacement server:

1. Put the new server on the tailnet with SSH access (Kamal installs Docker).
2. Point `deploy.server` in the credentials at it, and put a new auth key in the
   `tailscale` credentials, since the old node's state stays on the dead server.
   Delete the old `reminders` machine in the Tailscale admin console first, so
   the new one gets the same name.
3. Boot Litestream before the app, so the app doesn't create an empty database
   first, then connect the vault again (step 4 of [First deploy](#first-deploy)):
   ```sh
   bin/kamal server bootstrap
   bin/kamal accessory boot litestream
   bin/kamal accessory logs litestream   # look for the restore, then "replicating to"
   bin/kamal deploy
   bin/kamal accessory boot tailscale
   bin/kamal accessory boot obsidian
   ```

### Restoring an earlier point in time

To roll the existing server back, restore into a new file, swap it in, and clear
Litestream's local state so it snapshots the rolled-back database:

```sh
bin/kamal app stop
bin/kamal accessory stop litestream
bin/kamal accessory exec litestream "-c 'cd /rails/storage && litestream restore -timestamp 2026-10-01T00:00:00Z -o restored.sqlite3 /rails/storage/production.sqlite3 && rm -rf production.sqlite3-wal production.sqlite3-shm .production.sqlite3-litestream && mv restored.sqlite3 production.sqlite3 && chown 1000:1000 production.sqlite3'"
bin/kamal accessory start litestream
bin/kamal app boot
```

The accessory's entrypoint is `/bin/sh`, hence the `-c`. Leave out `-timestamp`
to restore the latest backup.
