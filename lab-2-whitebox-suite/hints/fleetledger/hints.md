# FleetLedger hints

**Tier 1 - nudges**

- The service is white-box and small: read `fleetledger/src` and
  `fleetledger/db/` end to end before sending a single request. Map every
  endpoint and note where each parameter flows.
- `QueryGuard` is the only thing standing between you and the SQL. Read
  its code as a *pipeline*: what exactly happens to your input, and in
  what order? What does one pass over a list mean for an input that
  contains a blocked word *inside* a blocked word?
- Two different sinks, two different shapes of what you get back: one
  returns full rows, the other a single number. Which one lets you read
  data, and which one forces you to ask yes/no questions?
- The operator console checks an API key - but where does that key live,
  and which sink can read that table?

**Tier 2 - strong hints**

- The filter removes each keyword **once** (Java `String.replace`), so a
  token nested inside itself survives: `selselectect` -> `select`. Derive
  the nested form for every blocked token you need - including `pg_sleep`
  and `create`.
- The filter also strips `;`, `--`, `/*` and `*/`, and it **lowercases
  everything**. Consequences you must derive yourself: no comment
  terminator (balance the template's trailing quote - note the search
  sink appends `%'` while the stats sink appends `'`), and Postgres
  `LIKE` is case-sensitive, so `LIKE 'flag%'` will never match a stored
  `FLAG{...}` (the atlas lesson was "know your database" - this is it
  again from the other side).
- The stats sink is a COUNT: you cannot read rows out of it. That is your
  timing-oracle sink. Put the CASE inside an OR arm guarded by a row
  that exists (`name like 'helios-dawn'`), keep constants on the AND
  side - an OR arm that is constant-true gets folded away by the planner
  and the sleep never runs. `PG_SLEEP` returns `void`; check what
  `void IS NOT NULL` gives you.
- FLAG 1: UNION-extract the admin `api_key` from `users` through the
  search sink (mind the trailing `%'`), then call the console with it.
- FLAG 3: the app connects as a PostgreSQL **superuser** (read
  `01-init.sql`), and the console runs arbitrary (scrubbed) SQL. The
  database image ships a C helper at `/opt/fleet_exec.so` - the classic PostgreSQL UDF primitive. `CREATE FUNCTION` it, call it. The
  flag is in the postgres process environment, and remember the console
  lowercases *and* strips `;` - so your shell payload is one
  case-insensitive command line.

**Tier 3 - spoilers**

- See `solutions/fleetledger-solution.md`.