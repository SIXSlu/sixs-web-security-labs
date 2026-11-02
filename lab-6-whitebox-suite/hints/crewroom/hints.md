# CrewRoom hints

**Tier 1 - nudges**

- The wall is a static page plus a JSON API. Read `public/wall.js`
  before anything else: how exactly does a notice body end up on the
  page, and what does that mean for HTML you pin yourself?
- Who else reads the wall? Something taps in as the stationmaster every
  few seconds and keeps a session in `localStorage`. Which endpoint
  mints that session, how long does it live, and what could see it from
  inside a notice?
- The railway's browser policy (`Content-Security-Policy`, check the
  response headers) forbids the page from talking to any origin but
  itself. An XSS that wants to ship data out has exactly one place left
  to put it - and you can read that place too.
- For the second flag: read the settings endpoint's merge helper slowly.
  It walks every key of your JSON with the same blind trust. Which
  object does every JavaScript object inherit from, and what happens
  when your key happens to be the name of that relationship?

**Tier 2 - strong hints**

- `POST /api/notices` with a body containing an inline event handler on
  a same-origin element (`<iframe src="/sixs.css" onload="...">`) - the
  handler runs in the wall page where `localStorage` holds the bot's
  admin tap. Make the handler POST a second notice containing the tap;
  then poll `GET /api/notices` for your drop and replay the tap
  (`Authorization: Bearer ...`) at `GET /api/admin/briefing` within its
  60-second lifetime.
- The stationmaster's password is minted at deploy time and never lives
  in the source - you cannot log in as the bot. You can only rob it.
- `express.json()` strips the classic `__proto__` key from your JSON on
  the way in (body-parser grew prototype-pollution defences). The merge
  is still blind: send `{"constructor": {"prototype": {...}}}` - the
  merge resolves `settings["constructor"]` to `Object` and walks its
  `prototype` into `Object.prototype`.
- Node's `child_process` ignores *inherited* options on current Node -
  the old `Object.prototype.shell` gadget is dead at the platform level.
  Instead, read the backup handler: which settings key does it consult,
  and what does your pollution make that lookup return? Then give the
  archiver an `archive` tag with shell metacharacters and a setuid
  helper path.

**Tier 3 - spoilers**

- See `solutions/crewroom-solution.md`.