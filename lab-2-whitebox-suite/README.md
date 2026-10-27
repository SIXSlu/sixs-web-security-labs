# White-Box Suite II - Three Vulnerable Services

> A **SIXS** security training lab · shipped with bugs, as a feature · no refunds, no warranty, no mercy

Three more deliberately vulnerable services, each a fresh instance of a classic
web-exploitation archetype (SQLi->RCE, PRNG->SSTI, `php://filter` and restricted
`eval`) in a new aplication with new filters to derive - so nothing is muscle
memory from a published walkthrough.

**White-box**: the full source of every application ships in this directory.
Audit the source, find the bugs, and write stable, repeatable exploits that
finish every chain to a proven flag. Flags are generated **fresh at every
container start**.

## Running

```bash
docker compose up --build -d
docker compose logs -f         # watch startup
docker compose down            # stop (re-run restarts with new flags)
```

| Service | Target | Stack | Ports |
|---|---|---|---|
| Challenge 1 | FleetLedger vessel registry | Java 17 / Spring Boot + PostgreSQL 16 | `http://localhost:8084` (JDWP `18001`) |
| Challenge 2 | CaseForge support desk | Python 3.12 / Flask + Jinja2 | `http://localhost:8085` |
| Challenge 3 | PrintBay print-shop CMS | PHP 8.3 / Apache + SQLite | `http://localhost:8086` |

The FleetLedger database is not published to the host: SQLi is your only door
into it. Enable PostgreSQL statement logging as a debugging aid:

```bash
docker compose exec fleetledger-db sh -c "psql -U postgres -c \"ALTER SYSTEM SET log_statement='all';\" -c \"SELECT pg_reload_conf();\""
docker compose logs -f fleetledger-db
```

## Ground rules

1. **Audit first.** Map every endpoint from the source before you send a single
   request.
2. **Write each exploit as a standalone, argument-driven script** in
   `exploits/` (e.g. `python3 my_exploit.py --ip 127.0.0.1 --port 8084`). The
   deliverable is a working PoC a third party can run unchanged.
3. **Finish every chain.** Only a flag your script printed, counts.
4. **No peeking.** `hints/` is tiered (nudge -> strong hint -> answer).
   `solutions/` is for after you have the flag. `docker exec` reading of flag
   values is also peeking.
5. **QA your code.** Run your exploit twice from scratch before calling it done.

## The challenges and what they train

Each flag is a chain stage, ordered. Flags rotate at every container start.

### Challenge 1 - FleetLedger (`fleetledger`, Java + PostgreSQL)

Everything here is SQL injection, and the filter is new.

* **FLAG 1 - filter bypass + UNION extraction:** a pre-auth search endpoint
  concatenates into SQL behind a keyword blocklist that removes each token
  *once*. Derive the bypass from the filter's code, read the operator API key
  out of the users table, and walk into the admin console.
  *Trains: single-pass-removal bypasses, UNION payload construction, quote
  balancing without comment terminators.*
* **FLAG 2 - time-based blind SQLi:** a second sink only returns a scalar, so
  rows cannot be read out. Extract the maintenance master key through the
  timing oracle - with the same filter in the way, and a PostgreSQL
  case-sensitivity trap.
  *Trains: timing-oracle scripting, planner-aware payload shaping, DB
  fingerprinting.*
* **FLAG 3 - SQLi-to-RCE via UDF:** the app connects as a PostgreSQL superuser
  and the operator console runs arbitrary (filtered) SQL. `CREATE FUNCTION`
  against a C helper shipped in the DB image, then command execution - the flag
  lives only in the postgres process environment.
  *Trains: the UDF RCE primitive, working around a filter that lowercases and
  strips `;`.*

### Challenge 2 - CaseForge (`caseforge`, Python + Jinja2)

Magic links to get in, template engine to get RCE.

* **FLAG 1 - magic-link token prediction:** the passwordless-login token
  generator is seeded from wall-clock time - in Python this time. Re-implement
  the generator faithfully (it is not an LCG - read how `random.Random` is
  constructed and used), brute-force the seed window, and take over the admin
  session.
  *Trains: PRNG token prediction in a new language, seed-window spraying.*
* **FLAG 2 - SSTI behind a character filter:** the admin template preview
  renders user bodies with plain Jinja2 - after stripping the two characters
  every copy-pasted payload is full of. Derive a payload that never contains
  them.
  *Trains: SSTI payload derivation from the engine's own rules (string escapes,
  `|attr()`), not from a cheat sheet.*

### Challenge 3 - PrintBay (`printbay`, PHP + SQLite)

PHP wrappers, filters, and a restricted `eval`.

* **FLAG 1 - LFI to config leak:** the theme loader feeds `include()` a path
  guarded by a naive protocol/path check. Use the PHP wrapper family to read
  source, steal the support backdoor token, and open the admin panel.
  *Trains: `php://filter` source disclosure, wrapper selection.*
* **FLAG 2 - php://filter chain to RCE:** the same `include()` sink executes
  *bytes* - synthesise a PHP payload purely from filter conversions (the
  filter-chain technique, generated by your own exploit), no file write, no
  `allow_url_include`.
  *Trains: the filter-chain generator, end to end.*
* **FLAG 3 - restricted eval bypass:** the admin scriptlet engine blocks
  dangerous function names. The blocked words never appear in your code if the
  function name arrives as data - reach for reflection.
  *Trains: blocklist bypasses via PHP reflection.*

## Directory layout

```
fleetledger/    Challenge 1 source (Java) + postgres bootstrap + UDF helper
caseforge/      Challenge 2 source (Python)
printbay/       Challenge 3 source (PHP)
hints/          3-tier hints per challenge (nudge -> strong -> spoils)
solutions/      Full walkthroughs + reference exploits
exploits/       Put your own exploit scripts here
```
