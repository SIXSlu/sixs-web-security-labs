# HarborDock hints

**Tier 1 - nudges**

- Flag 1: `QueryGuard.sanitizeSearch` removes the space *character*
  and the `--` marker. SQL is more forgiving about word separators
  than you think - what other characters count as whitespace in a
  Postgres query, and which of them survive a filter that only knows
  the literal `" "`?
- Flag 1: no comment terminator available, so the injected query has
  to end up *syntactically *closed* - count every quote you open and
  find which one the template's own tail closes for you.
- Flag 2: why are there two logins in `01-init.sql`, and which tables
  can each one read? That answers "which endpoint can even see the
  vault" before you write a single payload.
- Flag 2: the sink returns a scalar and strips `union` outright. When
  rows are impossible but errors are reflected (see the app's error
  settings), what does Postgres do when you force it to cast text
  where an integer belongs?
- Flag 3: `mergeDeep` walks every key of the patch, including one very
  special key that "exists" on everything. Where does `target[key]`
  land when the key is not a normal key?
- Flag 3: the dashboard template guards an undefined variable with
  `typeof` - why is that written that way, and what name does the
  compiled render function look at that an option name could reach?

**Tier 2 - strong hints**

- Flag 1: `ILIKE '%'||'%'` - the template is
  `... ILIKE '%<q>%' ORDER BY id`. Send tabs (`%09`) as the word
  separators, open your payload with a quote, and let the template's
  trailing `%'` close the string you open at the end (`WHERE '1'='1`
  makes the leftover `%'` part of a balanced condition). UNION SELECT
  five columns to match the search SELECT.
- Flag 1: the flag note is a row of `system_notes`, and the search
  login is granted to that table - that part is UNION-able.
- Flag 2: the API token and the `seal` row are in `token_vault`, and
  only the stats login can read it. `(SELECT CAST(value AS int) FROM
  token_vault WHERE label='seal')` raises an error that names the
  value verbatim; the error body is in the 500 response because the
  debug include flags are on. Watch the label filter, and cast for the
  token the same way.
- Flag 2: the token doubles as the console credential - `POST
  /api/session {"token": ...}` returns a bearer session.
- Flag 3: pollute through `PUT /api/runtime` with a `settings` object
  whose only key is the property name every object inherits from.
  Give it the render engine's option whose value is spliced **raw**
  into the compiled function preamble (`outputFunctionName`) - build
  your gadget string so it both closes the `var x` statement and
  defines `var diagnostics = ...execSync('/usr/local/bin/readflag')...`,
  then GET `/dashboard` and read the diagnostics pre.
- Flag 3: verify the console's template-engine version against your
  notes before trusting the option-name gadget - versions past a
  certain point validate that identifier.