# SnipVault hints

**Tier 1 - nudges**

- Read `app/app.py` top to bottom - it is one file. Note how sessions
  work ("stateless signed pickle") and how the preview endpoint builds
  its file path.
- The preview endpoint's traversal filter is a *single-pass* replace.
  You have met single-pass replaces before. What does `"..././"` become
  after one pass?
- Before you fire a single LFI request, write the checklist of files you
  want to read and why. The lesson: a file-read primitive
  is useless without a target list.

**Tier 2 - strong hints**

- Target list, in order: the app's own config file (path is hardcoded in
  the source - read it), the deployment key inside it, the service
  account's home directory contents (no directory listing here, so
  reason about *likely* filenames from the entrypoint's perspective -
  read `entrypoint.sh` as a hint of layout), `/proc/self/environ`.
- Once you hold the HMAC key, the session token is fully forgeable.
  The token body is not JSON, not base64-of-JSON - look at the first
  bytes after you decode the base64 (`\x80\x03...` should ring a bell).
- Python's pickle executes the `__reduce__` tuple at load time. The
  app unpickles on *every* request that carries a token, so the
  forged cookie is both the delivery and the trigger.
- Exfil pattern (a common file-upload-chain trick): drop the flag into
  the publicly served directory instead of trying to read it back
  through the crash. Check where Flask serves `/static/` from.

**Tier 3 - spoilers**

- See `solutions/snipvault-solution.md`.