# Boss Lab III - TideGate (fused chain)

> A **SIXS** security training lab · here we prove, that XML really was a mistake

One deliberately vulnerable target: **TideGate**, a harbour EDI / customs
**manifest gateway** (PHP + SQLite). This is a single **fused chain** across
three bug classes - unauthenticated **blind SQL injection**, **XXE** file
read, and an XML **XSLT mapping** sink - where each stage hands the next the
credential or knowledge it needs.

**White-box**: the full source of the container ships in this directory.
Audit the source, find the bugs, and write a stable, repeatable exploit that
finishes the chain to a proven flag. Flags are generated **fresh at every
container start**.

## Running

```bash
./build.sh                      # pre-builds the image + docker compose up -d
docker compose logs -f          # watch startup
docker compose down             # stop (re-run restarts with new flags)
```

| Container | Target | Stack | Ports |
|---|---|---|---|
| Challenge | TideGate manifest gateway | PHP 8.3 / Apache + SQLite | `http://localhost:8091` |

A plain `docker compose up --build -d` works too; `build.sh` is only needed on
a host whose Docker daemon cannot reach the internet from the default bridge
during a build.

## Ground rules

1. **Audit first.** Map every endpoint from the source before you send a
   single request.
2. **Write the exploit as a standalone, argument-driven script** in
   `exploits/` - monolithic, standard library plus the usual HTTP client only.
3. **Finish the chain.** Only a flag your script printed, counts.
4. **No peeking.** `hints/` is tiered (nudge -> strong hint -> answer).
   `solutions/` is for after you have the flag.
5. **QA your code.** Run the exploit twice from scratch (`docker compose down
   && docker compose up -d`) before calling it done. Fresh flags every start
   mean a stale script cannot pretend.

## The chain - what each flag trains

### FLAG 1 - unauthenticated blind SQLi -> credential lift

The public consignment tracker (`/track.php`) folds the reference straight
into its lookup, but the page only ever tells you **one bit**: whether a
manifest matched. That is a boolean oracle, not a data dump. The thing worth
reconstructing through it is not the flag alone - it is the **partner API
token** in the `partners` table, the credential the ingestion endpoint demands
in the next stage. FLAG 1 sits in a row (`ops_secrets`) that no page prints;
lift it the same way.

*Trains: finding injection in a yes/no endpoint, building a boolean (or
timing) oracle, char-by-char extraction of a credential - not just a flag -
from an unauthenticated surface.*

### FLAG 2 - XXE -> file read (LFI)

With the partner token, `POST /gateway/ingest.php` accepts a manifest XML
document and returns a clearance receipt that **echoes the declared consignee
back to you**. The parser is left with entity substitution and DTD loading
on, and external entities are not filtered. Define one, point it at a file,
and read the receipt. The same primitive reads the gateway's **own source** -
which is how you learn the shape of the next stage.

*Trains: classic XXE against an in-band reflection sink, `file://` and
`php://filter` for file and source disclosure, reading a service's source to
find the next sink.*

### FLAG 3 - XML field-mapping sheet -> RCE

The gateway offers partners a convinience: a manifest may carry a
`<MappingSheet>` - an **XSLT stylesheet** the gateway applies to normalise
field names. It is applied with PHP functions registered. Derive a sheet that
does more than map fields. The final flag is the quarterly **seal**, which is
root-only and readable only through a setuid helper - so a file read will not
reach it; you need real command execution.

*Trains: XSLT injection via `php:function`, turning an XML-transform feature
into command execution, reaching a root-only resource that forces genuine
code execution rather than another file read.*

## Directory layout

```
tidegate/      gateway source (PHP/Apache + SQLite) + seal helper
hints/         3-tier hints (nudge -> strong -> spoils)
solutions/     full walkthrough + reference exploit
exploits/      put your own exploit scripts here
```
