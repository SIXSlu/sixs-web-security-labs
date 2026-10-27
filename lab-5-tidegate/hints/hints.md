# TideGate hints

**Tier 1 - nudges**

- Flag 1: read `tidegate/app/track.php`. The reference is concatenated into
  the query, but look at what the page actually returns - it is the *same*
  message shape whether or not your injected condition holds. What can you
  still learn from a single yes/no?
- Flag 1: the prize is not only the flag. Read `init_db.php` and ask which
  value in that database the *next* endpoint is going to ask you for.
- Flag 2: read `tidegate/app/gateway/ingest.php`. Which `libxml` options does
  it pass to `loadXML`, and which field does the receipt echo back verbatim?
- Flag 2: an XXE that reads a file can also read a *source file*. Line up the
  next stage before you leave this one.
- Flag 3: the same endpoint does a second thing with your document when it
  contains one particular element. Find it in the source and read how the
  stylesheet is run.

**Tier 2 - strong hints**

- Flag 1: base your payload on a reference that exists, e.g.
  `TG-1001' AND (<condition>) -- -`; a true condition keeps the row, a false
  one drops it. Extract char by char with
  `unicode(substr((SELECT ...),i,1))` and a binary search over the code
  point. Pull `partners.api_token` (you need it next) and
  `ops_secrets.v` (FLAG 1).
- Flag 1: SQLite has no `SLEEP`, but a boolean oracle needs none; if you want
  a timing channel instead, a correlated heavy subquery
  (`randomblob`/`count`) gives you one.
- Flag 2: `loadXML($body, LIBXML_NOENT | LIBXML_DTDLOAD)` substitutes
  entities and loads the DTD, and external entities are not blocked. Put a
  `<!DOCTYPE … [<!ENTITY x SYSTEM "file:///opt/tidegate/flag_manifest.txt">]>`
  in front of a `<Manifest>` and use `&x;` as the `<Consignee>`. Send the
  partner token in `X-Partner-Token`. FLAG 2 comes back on the receipt's
  `consignee:` line. Swap the entity for
  `php://filter/convert.base64-encode/resource=/var/www/html/gateway/ingest.php`
  to read the source.
- Flag 3: a `<MappingSheet>` child that is an `<xsl:stylesheet>` is applied
  with `XSLTProcessor::registerPHPFunctions()` on. With the namespace
  `xmlns:php="http://php.net/xsl"`, `php:function('system', '…')` runs a
  command. The flag is root-only; run the one thing that can read it:
  `php:function('system','/opt/tidegate/readflag')`. Its output lands on the
  receipt.
