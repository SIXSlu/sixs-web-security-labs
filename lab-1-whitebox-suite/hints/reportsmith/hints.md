# ReportSmith hints

**Tier 1 - nudges**

- Three places call `deepMerge`. Trace what each merge does and, more
  importantly, *how* the merge iterates and assigns. `for...in` and the
  `__proto__` accessor are the whole story.
- Send a theme with `{"__proto__": {"something": true}}` and then check
  `GET /api/me` and `({}).something` behavior. Why does
  `JSON.parse` give you an *own* `__proto__` property, and why does the
  merge write through to `Object.prototype`? If you cannot answer that
  from memory, this is exactly the mental model to build - no course
  notes this time.

**Tier 2 - strong hints**

- FLAG 1: some feature flags start disabled and are read from a merged
  settings object. A polluted `Object.prototype` fills in "missing"
  attributes for every object built after the pollution.
- FLAG 2: the report renderer passes a *merged options object* to the
  template engine. Open `node_modules/ejs/lib/ejs.js` inside the
  container (or `npm install` locally) and grep for how the template
  function is built - which option is interpolated *into generated
  code*? That is your gadget.
- Craft the payload so the injected statement survives in
  `var <option> = '';` and then exfiltrate by copying the flag file into
  the directory served under `/` (check `express.static`).

**Tier 3 - spoilers**

- See `solutions/reportsmith-solution.md`.