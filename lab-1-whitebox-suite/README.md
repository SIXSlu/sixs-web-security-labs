# White-Box Suite I - Three Vulnerable Services

> A **SIXS** security training lab · built to be broken on purpose · if it works on the first try, you did something wrong

Three deliberately vulnerable services covering distinct bug classes. This lab
is **white-box**: the full source of every application ships in this directory.
Audit the source, find the bugs, and write stable, repeatable exploits that
finish every chain to a proven flag. Flags are generated **fresh at every
container start** - you cannot know a flag value without actualy exploiting
the service.

## Running

```bash
docker compose up --build -d
docker compose logs -f         # watch startup
docker compose down            # stop (re-run restarts with new flags)
```

| Service | Target | Stack | Ports |
|---|---|---|---|
| Challenge 1 | ATLAS asset registry | Java 17 / Spring Boot + PostgreSQL 16 | `http://localhost:8081` (JDWP `18000`) |
| Challenge 2 | SnipVault paste service | Python 3.12 / Flask + pickle | `http://localhost:8082` |
| Challenge 3 | ReportSmith reporting | Node 20 / Express + EJS | `http://localhost:8083` |

The databases are not published to the host: SQLi is your only door into them.
PostgreSQL statement logging is off by default; enable it as a debugging aid:

```bash
docker compose exec atlas-db sh -c "psql -U postgres -d atlas -c \"ALTER SYSTEM SET log_statement='all'; SELECT pg_reload_conf();\""
docker compose logs -f atlas-db
```

## Ground rules

1. **Audit first.** Map every endpoint from the source before you send a single
   request. Build a quick regex/grep triage rather than eyeballing files one by
   one.
2. **Write each exploit as a standalone, argument-driven script** in
   `exploits/` (e.g. `python3 my_exploit.py --ip 127.0.0.1 --port 8081`). The
   deliverable is a working PoC a third party can run unchanged.
3. **Finish every chain.** A flag you "know how to get" does not count - only a
   flag your script printed counts.
4. **No peeking.** `hints/` is tiered (nudge -> strong hint -> answer).
   `solutions/` is for after you have the flag. Reading flag values out of
   containers with `docker exec` is also peeking.
5. **QA your code.** Run your exploit twice from scratch (`docker compose down
   && docker compose up -d`) before you call it done.

## The challenges and what they train

Each challenge has **2-3 flags**, ordered by chain stage. Flags rotate at every
container start.

### Challenge 1 - ATLAS (`atlas-api`, Java + PostgreSQL)

* **FLAG 1 - auth bypass:** predict a password-reset token and take over the
  admin account. The token generator is in plain Java; re-implement it
  faithfully in your exploit language (the whole PRNG).
  *Trains: reading Java/Spring, `java.util.Random` prediction, base62.*
* **FLAG 2 - blind SQLi:** a low-privilege account finds a searchable endpoint
  with a sanitizer in the way. Extract the flag **through a timing oracle**
  (boolean-via-rowcount also works, but time-based is the target skill here).
  *Trains: filter-bypass derivation, time-based blind extraction, DB
  fingerprinting - know *what* database you are talking to before using its
  syntax.*
* **FLAG 3 - SQLi-to-RCE:** an admin-only DBA console gives you arbitrary SQL
  and a superuser account. Prove command execution: the flag exists only in the
  database container's environment and must be exfiltrated via command
  execution - callback to a listener, or drop-and-readback.
  *Trains: PostgreSQL-specific RCE primitives, verifying RCE with proof.*

### Challenge 2 - SnipVault (`snipvault`, Python + pickle)

* **FLAG 1 - LFI:** a file-preview feature has a naive traversal filter. Steal
  the deployment configuration. Build a read-target checklist before firing
  requests.
* **FLAG 2 - deserialization RCE:** the session token is not what it looks
  like. Recognise the pickle and weaponise it - `__reduce__`, webroot drop.

### Challenge 3 - ReportSmith (`reportsmith`, Node + EJS)

* **FLAG 1 - prototype pollution:** find the merge sink yourself (a hand-rolled
  function, not lodash - no advisory names it for you), understand *why* the
  pollution works (getter/setter, own-vs-inherited), then use it to flip an
  authorization check.
* **FLAG 2 - gadget hunting:** the RCE gadget lives in a dependency. Read the
  installed template engine and find the option that turns pollution into code
  execution. Derive the payload from the engine's source.

## Directory layout

```
atlas-api/     Challenge 1 source (Java) + postgres bootstrap
snipvault/     Challenge 2 source (Python)
reportsmith/   Challenge 3 source (Node)
hints/         3-tier hints per challenge (nudge -> strong -> spoils)
solutions/     Full walkthroughs + reference exploits
exploits/      Put your own exploit scripts here
```
