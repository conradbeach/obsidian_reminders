# Obsidian Reminders

Sends push notifications for reminders written in Obsidian notes. The notes stay
in Obsidian, organized however she likes; this app only reads them.

## Writing reminders

Put `(@` + a time + `)` on any line of a note: `- [ ] Call the dentist (@tomorrow 9am)`.
The app's guide (the **?** in its header, at `/guide`) explains every form a time
can take and how reminders behave. Its source is `app/views/guides/show.html.erb`.

## API

Other apps, like the Omarchy bar widget in
[conradbeach/dotfiles](https://github.com/conradbeach/dotfiles), use the same
routes as the web app with `.json` and a user's API token, which they create
or replace in **Settings**:

```bash
curl -H "Authorization: Bearer $TOKEN" https://reminders.example.ts.net/reminders.json
```

A missing or wrong token gets `401 Unauthorized`. The token works only for the
routes below. Times are ISO 8601 in the
app's time zone (Mountain).

### `GET /reminders.json`

The user's reminders that have a time, soonest first, overdue ones included.
A reminder is overdue once it's `overdue_after_hours` past its `remind_at`.

```json
{
  "overdue_after_hours": 24,
  "reminders": [
    {
      "id": 12,
      "text": "Take vitamins",
      "remind_at": "2026-10-22T08:00:00.000-06:00",
      "recurring": true,
      "note_path": "Conrad/Health.md",
      "heading": "Daily",
      "notes": "With breakfast"
    }
  ]
}
```

`heading` (the nearest heading above the reminder's line) and `notes` (the
lines nested under it) may be `null`.

### `POST /reminders.json`

Adds a reminder to the end of the user's note for new reminders, like the add
form does. Takes `reminder_addition[text]` and `reminder_addition[time]` (any
time a directive takes, without `(@` and `)`), as form or JSON parameters:

```bash
curl -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"reminder_addition": {"text": "Call the dentist", "time": "tomorrow 9am"}}' \
  https://reminders.example.ts.net/reminders.json
```

Responds `201 Created` with the reminder, shaped as above, or
`422 Unprocessable Content` with `{"errors": ["Needs a clearer time. Couldn't understand “whenever”."]}`.

### `POST /reminders/:id/completion.json`

Marks the reminder done, like its circle in the app: a repeating reminder moves
to its next occurrence; any other is checked off in its note. Responds
`204 No Content`, or `404 Not Found` if it isn't one of the user's reminders.

## How it works

- **Obsidian Headless** ([`ob`](https://obsidian.md/help/sync/headless)) runs as
  a Kamal accessory and keeps a copy of the vault in two-way sync with Obsidian
  Sync, running a one-shot `ob sync` every 30 seconds (its continuous mode
  silently stopped receiving changes). Its sync state lives in the vault volume
  (`/vault/.ob-state`), so the two can't be lost separately: state outliving a
  wiped vault would look like every note being deleted.
- The app changes notes in three ways: it adds reminders made in the app to
  the user's note (`Vault#append`), checks off a reminder's line
  (`CheckOffReminderJob`, `Vault#check_off`), and ends a new reminder's line
  with an Obsidian block ID (`IdentifyReminderJob`, `Vault#identify`). It edits
  only a line unchanged since the last scan; replaces the note in one step;
  and holds a lock (`/vault/.reminders.lock`) that each sync also holds, so it
  never edits a note mid-sync. If the lock is busy it retries.
- A reminder is matched to its line by the line's block ID (`^K3P9`), so its
  words can change, or it can move to another note, and keep its time; a
  changed directive is read again. A line without an ID of its own (a new one,
  one with several directives, or a copy of another reminder's line, which
  gets a new ID) is matched by its note, line, and directive. The ID is added
  two minutes after a reminder is first scheduled, so it doesn't land in a line
  someone's still typing, and only if someone receives it: notes outside
  everyone's folders, or in their ignored folders, are never edited.
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

### The parser

Reading directives (`app/models/reminder/directive.rb`, `clock.rb`,
`calendar_date.rb`, and `recurrence/`) is the most intricate part of the app,
and a misread is the worst failure it has: a reminder that goes off on the wrong
day looks fine, and nothing says it's wrong. So the parser's specs are tables of
directives and the dates they mean, worked out by hand from a calendar rather
than copied from the parser's output:

- `spec/models/reminder/directive_spec.rb`: when each directive first goes off,
  including near misses that must stay unscheduled.
- `spec/models/reminder/recurrence_spec.rb`: the next occurrence from a given one,
  and each kind of repeat's first six occurrences, done on time and late.

Every change to the parser adds rows for what it reads, its wording variants,
its calendar edges (daylight saving, leap days, short months, year rollover),
and what it must not read. When a row disagrees with the parser, check the
calendar before changing the row.

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

### Checking the backup

`bin/check-backup` restores the latest backup from R2 beside the live database,
checks its integrity, compares its row counts and latest reminder change with
the live database's, and deletes the copy. It fails if the backup is damaged or
more than five minutes behind. Run it about once a month, and after changing
Litestream's version or settings; agents do so when `tmp/backup-checked` (which
it touches on success) is missing or over 30 days old.

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
