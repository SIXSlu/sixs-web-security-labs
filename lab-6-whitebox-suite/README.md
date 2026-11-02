# White-Box Suite III - Four Vulnerable Services in Perl and Node

> A **SIXS** security training lab · shipped with bugs, as a feature · no refunds, no warranty, no mercy

Three deliberately vulnerable services written in **Perl 5.38 / Mojolicious** — a
language that still runs a surprising share of the real-world intranet, and one
whose classic execution footguns never made it into the modern cheat sheets.
Every bug there is *Perl-specific*: regex code blocks, two-argument `open`,
string `eval`, signed-cookie session forging, YAML object
deserialization, and the string-form shell.

A fourth service, **CrewRoom**, moves the suite into **Node 20 / Express** with
a modern browser-side chain: a stored XSS that steals a short-lived admin
session from a live supervisor bot, and a prototype-blind settings merge that
turns the archive helper into a shell.

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
| Challenge 1 | FareDesk ticket-counter kiosk | Perl 5.38 / Mojolicious + SQLite | `http://localhost:8092` |
| Challenge 2 | TrackSide trackside defect log | Perl 5.38 / Mojolicious + regex + YAML | `http://localhost:8093` |
| Challenge 3 | SignalBox departure boards | Perl 5.38 / Mojolicious + SQLite | `http://localhost:8094` |
| Challenge 4 | CrewRoom crew notice wall | Node 20 / Express + jsdom supervisor bot | `http://localhost:8095` |

The databases are not published to the host and the flag seals are root-only
inside each container: the only doors in are the ones the source gives you.

## Ground rules

1. **Audit first.** Map every endpoint from the source before you send a single
   request.
2. **Write each exploit as a standalone, argument-driven script** in
   `exploits/` (e.g. `python3 my_exploit.py --ip 127.0.0.1 --port 8092`). The
   deliverable is a working PoC a third party can run unchanged.
3. **Finish every chain.** Only a flag your script printed, counts.
4. **No peeking.** `hints/` is tiered (nudge -> strong hint -> answer).
   `solutions/` is for after you have the flag. `docker exec` reading of flag
   values is also peeking.
5. **QA your code.** Run your exploit twice from scratch before calling it done.

## The challenges and what they train

Each flag is a chain stage, ordered. Flags rotate at every container start.

### Challenge 1 - FareDesk (`faredesk`, Perl + Mojolicious)

Counter terminals, a fare-previewing formula engine, and a printer spooler -
three doors, all of them classic Perl.

* **FLAG 1 - signed-session forgery:** the kiosk has no login; it trusts a
  signed session cookie from the "depot SSO". Find how Mojolicious signs that
  cookie and what was left in the source, then forge yourself an admin session
  offline - no request to any login ever needed. The console's ops banner is
  the prize.
  *Trains: signed-cookie session formats, why a committed signing secret is a
  complete auth bypass, forging the payload+HMAC in your exploit language.*
* **FLAG 2 - string `eval` behind a name blocklist:** the fare previewer
  "sanitizes" your formula by deleting dangerous builtin names and every
  quoting character, then `eval`s it as an expression. The blocklist blocks
  *names* - reach for what `perlop` documents as an *operator*.
  *Trains: Perl string eval, blocklist-vs-operator reasoning, expression-context
  payloads.*
* **FLAG 3 - two-argument `open` in pipe mode:** the dispatch route opens a
  pipe to the printer spooler with your printer name interpolated into the
  command string. Pipe mode is write-only, so the execution is *blind* - get
  the root-only seal out through a door the app itself serves.
  *Trains: two-arg `open` magic modes, blind command execution, out-of-band
  exfiltration through a web-served directory.*

### Challenge 2 - TrackSide (`trackside`, Perl + regex + YAML)

One small defect log, two of the most Perl-only bug classes there are.

* **FLAG 1 - regex code injection:** the search highlighter compiles your
  search term straight into a pattern. Normally Perl refuses to run
  interpolated code blocks in patterns at runtime - read what the controller
  had to load to make the "acceptance harness" work, and what runs when the
  engine walks past a `(?{ ... })`. Lift the commissioning seal and, with it,
  the staff import token for the next stage.
  *Trains: `use re 'eval'` and interpolated `(?{...})` blocks - code execution
  from inside the regex engine.*
* **FLAG 2 - YAML object deserialization:** the shift-handover import parses
  YAML with the old pure-Perl loader, which *blesses* what it loads into
  application classes. One shipped class has a destructor with a command
  field. Craft a handover that blesses attacker data into that class and lets
  scope exit do the rest - the root-only seal falls to it.
  *Trains: Perl object deserialization (`!perl/hash:`) as this ecosystem's
  pickle - blessing attacker data, DESTROY gadgets, command execution from a
  plain YAML mapping.*

### Challenge 3 - SignalBox (`signalbox`, Perl + Mojolicious)

The signalman's console: a tail logbox and a board announcer.

* **FLAG 1 - two-argument `open` read-mode pipe:** the tail logbox guards its
  `src` parameter against absolute paths and traversal, then hands the string
  to two-argument `open`. The guard inspects a *path* - but two-arg `open`
  never promised `src` was one. Read what the box never meant to show, and
  take the commissioning seal plus the console PIN with it.
  *Trains: read-mode command pipes (`cmd |`), and why the two-argument form
  turns path validation into theater.*
* **FLAG 2 - string-form shell execution:** unlocked with the PIN you lifted,
  the announcer interpolates your text into a `qx{...}` command line and
  returns its captured stdout on the page. One request, in-band.
  *Trains: string-form command execution in Perl, metacharacter injection,
  in-band output capture.*

### Challenge 4 - CrewRoom (`crewroom`, Node 20 + Express)

The crew notice wall, plus the duty stationmaster bot that watches it with a
live admin session. A modern chain: cross the browser boundary, then the
runtime's.

* **FLAG 1 - stored XSS -> admin tap hijack:** the wall renders notice bodies
  through `innerHTML`, and the stationmaster bot browses it every few seconds
  with a 60-second admin tap sitting in `localStorage`. The railway's browser
  policy (`connect-src 'self'`) means nothing can leave the station network -
  so the only way out for the stolen tap is back through the wall's own API.
  Replay it inside its lifetime and read the stationmaster briefing.
  *Trains: stored XSS against a headless admin bot, CSP-aware exfiltration
  through the application itself, short-lived token replay and the timing
  discipline that comes with it.*
* **FLAG 2 - prototype pollution -> shell-mode archiver:** the admin settings
  endpoint walks the incoming JSON with a merge that never learned what a
  prototype is, and Node's own parsers have grown defences - so the classic
  key does not survive the request. Find the merge's blind spot, pollute a
  setting the backup helper consults, and hand the archiver a shell line.
  The root-only seal falls to the setuid helper, in-band.
  *Trains: prototype-blind deep merges, `constructor.prototype` past
  body-parser's `__proto__` stripping, prototype pollution to command
  execution against a hardened runtime.*

## Directory layout

```
faredesk/       Challenge 1 source (Perl / Mojolicious)
trackside/      Challenge 2 source (Perl / Mojolicious + YAML)
signalbox/      Challenge 3 source (Perl / Mojolicious)
crewroom/       Challenge 4 source (Node / Express + jsdom bot)
hints/          3-tier hints per challenge (nudge -> strong -> spoils)
solutions/      Full walkthroughs + reference exploits
exploits/       Put your own exploit scripts here
```