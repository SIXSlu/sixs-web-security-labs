# FareDesk hints

**Tier 1 - nudges**

- The kiosk has no login form at all - so what *is* the staff console
  gate, and where does the thing it trusts come from? Read
  `lib/FareDesk.pm` before anything else, and remember a signature is
  only as good as its key.
- A Mojolicious session is a signed cookie. Two questions: what exactly
  is inside the signed part, and what is the signing key here? If you
  can name both, you can mint one yourself offline.
- The formula previewer deletes dangerous builtin *names* and every
  quoting character before `eval`. Open `perlop` and list the ways Perl
  runs commands that are *operators*, not named functions.
- The dispatch route hands your printer name to a two-argument `open`
  in pipe mode. What characters does Perl's shell interpret in there -
  and since the pipe is write-only, where can the *output* of a
  command go that you can still read?

**Tier 2 - strong hints**

- `Mojolicious::Sessions` signs the cookie as
  `base64(json payload) + "--" + HMAC-SHA1(payload, secret)`. Rebuild
  that by hand in your exploit language: payload
  `{"admin":1,"expires":<far future epoch>}`, base64 of the compact
  JSON, HMAC-SHA1 hex of that base64 text keyed with the secret
  committed in `lib/FareDesk.pm`, cookie name `faredesk`. Send it on the
  very first request - the console is the only thing that ever checks
  it.
- The formula blocklist strips `system exec open readpipe unlink print`
  and the characters backtick `' "`. The `perlop` entry for `qx` says
  it "is a synonym for" one of the blocked names - but the blocklist
  matches *text*, not operators. `qx{cat /opt/faredesk/flag_eval.txt}`
  contains no blocked word and no stripped character; scalar context
  captures the output and the page renders it as the "computed fare".
- The dispatch route is `open(my $lp, "| /opt/faredesk/bin/spool $printer")`.
  Metacharacters in `$printer` hand the whole line to `/bin/sh`. The
  command runs with the kiosk account, which cannot read the root-only
  seal - but there is a setuid helper under `/opt/faredesk` that can,
  and its stdout is yours to redirect. The app serves one directory
  straight to the web: `public/`. Redirect there, then GET it.

**Tier 3 - spoilers**

- See `solutions/faredesk-solution.md`.