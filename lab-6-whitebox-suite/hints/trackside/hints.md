# TrackSide hints

**Tier 1 - nudges**

- The search box compiles your `q` straight into the highlighter's
  pattern. Normally Perl *refuses* to run interpolated code blocks at
  runtime - so why does `(?{ ... })` compile here at all? Read the top
  of `lib/TrackSide/Controller/Entries.pm` and check what that pragma
  does in `perldoc re`.
- A code block inside a pattern runs *when the engine walks past it*
  during a match attempt - the overall match does not have to succeed.
  Anything inside `(?{ ... })` is ordinary Perl. Where does the search
  page's input ultimately end up, and what would you like that Perl to
  do with a file you cannot otherwise read?
- The import endpoint parses YAML with the old pure-Perl loader - not
  YAML::XS. What does that loader do with a `!perl/hash:` tag? And when
  a *blessed* object goes out of scope, what runs? Read the POD of the
  one app class that ships a destructor.

**Tier 2 - strong hints**

- Payload shape for the highlighter: `(?{ ... })x` - the leading block
  executes on the first match attempt regardless of what comes after;
  the trailing `x` is just there so the substitution finds something.
  Put a search term in your own filed entry to guarantee a match. Use
  the code block to `system()` the files you want into the web-served
  `public/` directory (both the commissioning seal and the import token
  travel in `/opt/trackside` - the token is stage 2's door).
- The handover endpoint checks `X-Import-Token` against
  `/opt/trackside/config/import.key` - which you lifted in stage 1 -
  and then `YAML::Load`s the raw request body with blessed loading
  enabled. Send:
  ```
  --- !perl/hash:TrackSide::ScrubJob
  cleanup_cmd: /opt/trackside/readflag > /opt/trackside/public/leak2.txt
  ```
  The loader blesses the mapping into the scrubber class; when `undef
  $notes` runs at scope exit the destructor pipes "purge" into your
  `cleanup_cmd` through another two-argument `open`. Fetch what you
  redirected. (If the loader chokes on the tag spelling, try the
  YAML-1.1 double-bang form `!!perl/hash:...`.)

**Tier 3 - spoilers**

- See `solutions/trackside-solution.md`.