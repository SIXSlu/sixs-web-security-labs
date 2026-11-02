# SignalBox hints

**Tier 1 - nudges**

- Compare, character for character, the string the tail logbox
  *validates* with the string it hands to `open`. Now read
  `perldoc -f open`, two-argument form: what does a trailing `|`
  mean, and does the guard have an opinion about that?
- The guard blocks leading `/` and `..` - it wants a relative file
  name. But two-arg `open` decides between "file" and "command" by
  looking at the *ends* of the string, not the middle. What can you
  put in the middle that a shell happily runs?
- For the second flag: the announcer is invoked through `qx{...}` with
  your text interpolated into the braces. `qx` captures stdout - and
  the controller renders that capture straight onto the page. List
  your metacharacter options; the flag needs only one request.

**Tier 2 - strong hints**

- `GET /ops/tail?src=cat /opt/signalbox/board.conf |` - the string
  neither starts with `/` nor contains `..`, but two-arg `open` sees
  the trailing pipe and spawns a shell instead of opening a file. The
  response body is the command's stdout. The box configuration carries
  both the commissioning seal (FLAG 1) and the `signalman_pin` that
  unlocks the console session (`POST /ops/unlock`, parameter `pin`).
- With the session cookie from the unlock, `POST /ops/broadcast` with
  `text=x; /opt/signalbox/readflag` - the semicolon chains your
  command after the announcer, `qx` captures both stdouts, and the
  rendered "board updated:" line carries the setuid helper's output
  in-band.
- The root-only seal file is unreadable for the signalman account; the
  setuid `readflag` under `/opt/signalbox` is the only reader - which
  is the point of the stage.

**Tier 3 - spoilers**

- See `solutions/signalbox-solution.md`.