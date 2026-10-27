# Boss Lab I - PaperTrail (fused chain)

> A **SIXS** security training lab · the one portal where the vulnerabilitys are the documentation

One deliberately vulnerable target: **PaperTrail**, a harbour document portal
(Flask) with an internal-only intranet CMS. Instead of seperate reps on
isolated archetypes, this is a single **fused chain** across three bug classes
(PRNG token prediction, SSRF, and template-engine RCE), where each stage hands
credentials or access to the next.

**White-box**: the full source of both containers ships in this directory.
Audit the source, find the bugs, and write a stable, repeatable exploit that
finishes the chain to a proven flag. Flags are generated **fresh at every
container start**.

## Running

```bash
./build.sh        # pre-builds the images + docker compose up -d
docker compose logs -f          # watch startup
docker compose down             # stop (re-run restarts with new flags)
```

| Container | Target | Stack | Ports |
|---|---|---|---|
| Challenge 1 | PaperTrail portal | Python 3.12 / Flask | `http://localhost:8088` |
| - | PaperTrail intranet | Python 3.12 / Flask | **no published port** |

The intranet is on a `back` network marked `internal: true`: there is no route
between it and your host in either direction. `docker exec` into it is peeking -
the only legitimate path to it is through the portal.

## Ground rules

1. **Audit first.** Map every endpoint from the source before you send a single
   request.
2. **Write the exploit as a standalone, argument-driven script** in
   `exploits/` - monolithic, standard library plus the usual HTTP client only.
3. **Finish the chain.** Only a flag your script printed, counts.
4. **No peeking.** `hints/` is tiered (nudge -> strong hint -> answer).
   `solutions/` is for after you have the flag.
5. **QA your code.** Run the exploit twice from scratch (`docker compose down
   && docker compose up -d`) before calling it done. Fresh flags every start
   mean a stale script cannot pretend.

## The chain - what each flag trains

### FLAG 1 - PRNG token prediction -> admin takeover

The passwordless sign-in flow is open to any address, and the link token is
generated server-side. The audit question is the classic one: *what is the
seed, and how much entropy is really in it?* Read `magiclink.py` and the
sign-in response carefully - the state is handed to you by the application
itself.

*Trains: PRNG state inference, faithful generator re-implementation, token
spraying at a verify endpoint.*

### FLAG 2 - reaching the intranet (SSRF pivot)

The admin desk has a *link inspector* that fetches a URL and renders an excerpt
back to you. The scheme guard is the only guard. The intranet's dashboard
trusts that its network segment does the gating and shows staff-only material
to anyone who arrives from inside. The source of both apps plus the compose
file will tell you the internal service name and port.

*Trains: SSRF as a pivot between trust zones, reading deployment topology out
of white-box source, content relay through the SSRF response.*

### FLAG 3 - code execution on the intranet

The intranet ships its own note renderer. Its review history is visible in the
source: one fix kills dunder attribute names, and another kills every
backslash - both true, neither sufficient. Derive a payload from the engine's
grammar using the characters that are still legal.

*Trains: SSTI payload derivation from first principles - constructing what
cannot be spelled; reaching a root-only resource, which forces genuine command
execution (not merely file reads).*

## Directory layout

```
papertrail/    public portal source (Python/Flask) + seed data
intranet/      internal CMS source (Python/Flask) + seal helper
hints/         3-tier hints (nudge -> strong -> spoils)
solutions/     full walkthrough + reference exploit
exploits/      put your own exploit scripts here
```
