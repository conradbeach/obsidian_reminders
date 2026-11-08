# AGENTS.md

The directive parser needs very thorough specs: a misread schedules a reminder on the wrong day with nothing to show
it's wrong. Read "The parser" in README.md before changing anything under `app/models/reminder/`, and add table rows,
with dates worked out by hand, for every change.

Run `bin/ci` before merging.

Check production's backup about once a month: if `tmp/backup-checked` is missing or more than 30 days old, run
`bin/check-backup` at the start of a session and tell the user the result. It restores the latest Litestream backup
from R2 beside the live database, compares the two, and deletes the copy; it doesn't change the live database.

Whenever I ask you to make changes and you believe you've completed the task, go ahead and deploy the application. This is a personal project that's only used by a couple of people; the risk is not high if something breaks. Obviously confirm that your deploy worked as expected and fix anything wrong, but you don't need to worry about bringing down the app for a few minutes; it doesn't really matter.
