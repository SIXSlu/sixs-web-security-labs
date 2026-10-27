# CaseForge hints

**Tier 1 - nudges**

- Read `app/magiclink.py` before anything else. Ask yourself one
  question: how many possible values can the seed of that generator
  take while you watch the clock?
- The verify endpoint is one-time and has **no rate limit** - why
  would a helpdesk rate-limit its own sign-in mail? What does that
  let you do with a list of candidate tokens?
- For the second flag: the preview route "sanitizes" the template body
  before rendering. List every character class it removes, then list
  every place a Jinja2 template *needs* those characters. The gap
  between those two lists is the challenge.
- The sanitizer strips *characters*, not *constructions*. Where in a
  Jinja2 expression can a needed character be *produced* at runtime
  instead of written literally?

**Tier 2 - strong hints**

- Seed window: request the magic link, note the time, and re-implement
  `generate_token()` in your exploit language - `random.Random(seed)`
  with the same alphabet, same length, same call order. Candidates for
  every second in a ±10s window around the request is plenty. Spray
  them at `/api/auth/magic/verify` and watch for the `Set-Cookie`
  header.
- The admin mailbox is in the seed data (`app/db.py`), not a secret.
- Jinja2 string literals are Python-style: escapes like `\x5f` and
  `\x2e` are decoded by the *lexer*, long before any sanitizer could
  matter - but the sanitizer runs on the *source text*, so your
  payload must contain zero literal dots and underscores **anywhere**,
  including inside the command string you hand to `popen()`. The flag
  path itself contains an underscore - remember that.
- Jinja2 grammar note: you cannot chain `[...]` or `(...)` directly on
  the result of a `|filter` - wrap filtered expressions in parentheses
  first, then subscript/call them.
- The render goes through plain `jinja2.Template(body).render()` with
  no sandbox, and `lipsum` is always in the default template globals.

**Tier 3 - spoilers**

- See `solutions/caseforge-solution.md`.