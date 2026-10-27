# ATLAS hints

**Tier 1 - nudges**

- The white-box part is the whole game: `atlas-api/db/01-init.sql` and
  `src/main/java/com/nimbus/atlas/` are small enough to read entirely.
  Build an endpoint map and a "where does user input flow" table first.
- Two independent weaknesses live in the auth area. One is about *what
  the accounts are*, the other about *how reset tokens are made*.
- The search endpoint has a filter between you and the SQL. Read the
  filter, then enumerate exactly what you can still send. Quotes are not
  on the blocklist - what does that enable? And what SQL construct
  separates tokens the same way whitespace does, if whitespace is gone?

**Tier 2 - strong hints**

- Default credentials: the DB bootstrap script mentions a provisioning
  password in a runbook comment. That is your low-privilege foothold.
- `TokenUtil.getRandomBase62` seeds `java.util.Random` with
  `System.currentTimeMillis()`. Re-implement the LCG in your exploit
  language (48-bit state, `next(31)` + rejection sampling in
  `nextInt(bound)`, the alphabet order matters) and spray candidate
  tokens for seeds around the moment you triggered the reset.
- For the SQLi: all whitespace plus `--`, `#` and `;` are stripped. Block
  comments survive the sanitizer, and PostgreSQL accepts `/**/` as a
  token separator - build the whole payload out of them. No comment
  terminator means you must balance the template's trailing quote; and
  pin the sleep to a single known row so the delay does not multiply
  per-table-row. `PG_SLEEP` returns `void` - check what that compares to.
  Know your database before choosing syntax.
- FLAG 3: once you are admin, an incident-response console runs arbitrary
  SQL *as the database user*. Check what that user is
  (`SELECT rolsuper FROM pg_roles WHERE rolname = current_user`), then
  think about what PostgreSQL lets a superuser execute server-side.
  The flag exists only in the container's environment - no SQL function
  reads env vars - so arrange delivery to yourself: either deliver to
  your own listener (busybox `wget` exists), or drop it into a file and
  read it back with the superuser file-read function.

**Tier 3 - spoilers**

- See `solutions/atlas-solution.md`.