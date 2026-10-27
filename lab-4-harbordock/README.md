# Boss Lab II - HarborDock + DockOps (fused chain)

> A **SIXS** security training lab · two services, one database, zero good decissions

One deliberately vulnerable target pair: **HarborDock**, a Java/PostgreSQL
manifest API, with a **DockOps** Node operator console riding on the same
database. The chain fuses SQLi-to-console work with a prototype-pollution ->
template-engine RCE, and adds two twists: the two endpoints sit behind
*different* query filters and *different* database priviledges (so the same tool
does not solve both sinks), and the console token only exists on the side of
the database your first login cannot read.

**White-box**: full source in this directory. Flags mint fresh every container
start via a `provision` service that writes into the database - nothing is
baked into images.

## Running

```bash
./build.sh        # pre-builds the images + docker compose up -d
docker compose logs -f          # watch startup
docker compose down             # stop (re-run restarts with new flags)
```

| Container | Target | Stack | Ports |
|---|---|---|---|
| Challenge 1 | HarborDock manifest API | Java 17 / Spring Boot 3 + PostgreSQL 16 | `http://localhost:8089` |
| - | DockOps operator console | Node 20 / Express + EJS | `http://localhost:8090` |

The PostgreSQL port is not published to the host: SQLi is the only door. Enable
statement logging as a debugging aid:

```bash
docker compose exec harbordock-db psql -U postgres -c "ALTER SYSTEM SET log_statement='all';" -c "SELECT pg_reload_conf();"
docker compose logs -f harbordock-db
```

## Ground rules

1. **Audit first.** The two filters live in `util/QueryGuard.java` and the two
   database logins (and their grants) in `harbordock/db/` - read both before
   attacking, because the right sink for each objective matters.
2. **Write the exploit as a standalone, argument-driven script** in
   `exploits/` - monolithic, standard library plus the usual HTTP client only.
3. **Finish the chain.** A flag your script printed, or it does not count.
4. **No peeking.** Tiered `hints/`, `solutions/` after the flag, no `docker
   exec` reading of flag values.
5. **QA.** Run the exploit twice from scratch before calling it done.

## The chain - what each flag trains

### FLAG 1 - search endpoint: filter bypass + UNION extraction

`/api/manifests/search` concatenates into an `ILIKE` behind a guard that
removes spaces and the line-comment marker. Derive the bypass from the guard's
code, balance the quotes without a terminator, and read the note that does not
belong in a search result.

*Trains: whitespace-bypass derivation in a PostgreSQL context, quote balancing
without comment terminators, UNION column alignment.*

### FLAG 2 - stats endpoint: a second filter, a scalar sink

`/api/ports/stats` returns a count - no rows, no UNION - and its own guard
removes a keyword outright. The vault table the token lives in is granted to
this endpoint's login and not to the search login's - the hint about which door
to use. Debug stack traces are shipped on.

*Trains: the DB-fingerprint step (which dialect features apply here?),
error-based extraction, reading privilege splits out of schema source.*

### FLAG 3 - DockOps console: prototype pollution -> RCE

The operator console authenticates with the vault token. Its runtime config
deep-merges operator settings by hand - the classic unguarded merge. The
console renders with a template engine whose version you should check against
the gadget list, and the dashboard has a slot that executes whatever the render
environment defines. The seal file is root-only, so the proof is execution.

*Trains: pollution->gadget derivation in a Node/EJS application (an option-name
gadget into engine-compiled code), auth token handling, and building the chain
so the exec result lands in an HTTP response you can parse.*

## Directory layout

```
harbordock/     Java source, pom, postgres bootstrap + provision script
dockops/        Node console source, seal helper
hints/          3-tier hints per flag (nudge -> strong -> spoils)
solutions/      full walkthrough + reference exploit
exploits/       put your own exploit scripts here
```
