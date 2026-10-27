# PaperTrail hints

**Tier 1 - nudges**

- Flag 1: read `papertrail/app/magiclink.py` end to end, then look at
  what the `/auth/request-link` response tells you back. A "seed"
  doesn't have to be a timestamp to be worthless - ask how many
  distinct values it can take *that you can observe*.
- Flag 1: the login page shows a job number when you queue a link.
  Ask yourself what else is a pure function of that same job number.
  Re-implement it exactly (order of calls matters).
- Flag 2: the compose file in this directory is part of the white-box
  audit. What is on the internal network that is not on yours?
- Flag 2: the inspector relays a *body excerpt* - decide early how
  much text comes back per fetch, because that shapes stage 3.
- Flag 3: read `intranet/app/app.py`, function `sanitize_note`, and
  list precisely what cannot survive it: the two-character dunder
  marker, and every backslash. Then list what the payload still needs
  and ask where each piece can come from instead of from source text.

**Tier 2 - strong hints**

- Flag 1: the token is `"-".join(f"{rng.getrandbits(32):08x}" ...)` -
  three times, in one fresh `random.Random(...)` per issue. The seed
  is the queue position, which the response shows you *after* the
  increment. So: send the admin's reset yourself and read your own job
  number; the token is computable on paper before the mail worker even
  blinks.
- Flag 1: the seeded admin mailbox is in `db.py`; the verify route is
  `/magic/<token>` and it hands you a session cookie on a clean 200.
- Flag 2: `POST /admin/inspect` with `http://intranet:9000/` after you
  are admin. The dashboard's own `remote_addr` check passes because
  your request originates from the portal container, not from you.
- Flag 2: the inspector fetches with `urllib` inside the container -
  the Docker DNS name, not `localhost`, is how the source of the
  request ends up internal.
- Flag 3: backslash-strip kills `\x`-style escapes entirely, so the
  names have to be *assembled at runtime*, not encoded. The `~`
  operator concatenates strings in Jinja2, and subscript brackets are
  untouched - so `lipsum[ <assembled> ]` needs no dots at all.
- Flag 3: after you reach `__globals__`, the same assembling trick
  reaches `__builtins__`; `__import__` is also a dunder key in that
  dict. The seal file is root-only for a reason - `open()` is not the
  win condition, running `/opt/intranet/readflag` is.