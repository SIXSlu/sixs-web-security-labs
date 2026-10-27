# PrintBay hints

**Tier 1 - nudges**

- Read `app/lib/theme.php` carefully. The previewer blocks traversal,
  absolute paths, and a list of *remote* wrappers. Enumerate the stream
  wrappers PHP actually ships and diff them against the blocklist. What
  can the missing wrapper do besides "read a file"?
- Stream-looking theme values go straight to `include()`. Ask what
  `include()` does with the *output* of a `php://filter` chain - and
  what `read=convert.base64-encode/resource=...` does to a file the web
  account can already read.
- Before firing a single request, write your file-read target list
  (the lesson: a read primitive is useless without targets).
  A small PHP app keeps deployment secrets in a file `entrypoint.sh`
  generates - read the entrypoint to learn the layout.
- `allow_url_include` is irrelevant for `php://` wrappers. If you can
  control *every byte* the `include()` evaluates, you have code
  execution without writing a file. How could a *filter chain* produce
  those bytes out of an empty stream?
- Read the `ScriptletEngine` blocklist like a typical PHP blocklist filter
  exercise: it rejects function *names*, not function *calls*. Where
  can a callable name come from at runtime, after the check has run?

**Tier 2 - strong hints**

- Stage 1 payload shape:
  `php://filter/read=convert.base64-encode/resource=/opt/printbay/config.php`.
  The base64 lands in the preview pane because PHP evaluates the
  encoded text as inert output. `config.php` holds the support hotline
  token; `?page=admin&token=...` boots an admin session and the staff
  console shows the ops banner.
- Stage 2: `php://temp` starts empty. `convert.iconv.UTF8.CSISO2022KR`
  seeds a known byte string, a base64-encode pins it, and then each
  `convert.iconv.X.Y` set grows the base64 text by one character of
  your choice. Build the base64 of `<?php system($_GET["c"]); ?>`
  *backwards*, one character per conversion set, re-encoding after
  each step; end with `convert.base64-decode` so the stream *is* the
  payload when `include()` evaluates it. Port the generator (the
  canonical tool is synacktiv's `php_filter_chain_generator`) - you
  need a conversion table entry for every base64 alphabet character,
  and the iconv table is glibc-specific, so verify empirically.
- Stage 3: the blocklist scans the snippet text only. `$_GET` is a
  superglobal - in scope inside `eval()`. A name that arrives via a
  request parameter never matches a static filter:
  `(new ReflectionFunction($_GET["f"]))->invoke($_GET["a"])` with
  `f=system` is generic RCE from the scriptlet sandbox; the endpoint
  also defines `printbay_flag3()` in scope. Note the filter's extra
  rule banning quote-dot-quote: simple string-building concatenation
  (`'sy'.'stem'`) is dead on arrival.

**Tier 3 - spoilers**

- See `solutions/printbay-solution.md`.