#!/usr/bin/env python3
"""
SIXS Web Security Labs - end-to-end flag test.

For every flag the lab stack issues, this asserts two independent things:

  1. CONTAINER side - the real flag value is actually present inside the
     container that hosts the challenge (read straight from where that
     lab's entrypoint puts it: a file, a DB row, or a process env var).
  2. PANEL side - submitting that exact value to the flag verifier
     ("our panel") returns {"ok": true}, and a tampered value is rejected.

Because it reads the container ground truth AND round-trips it through the
panel, it catches both classes of breakage we care about: a flag the panel
can no longer verify (hash drift / missing emit) and a flag the challenge
host no longer produces. It does NOT run the exploit chains - the per-lab
scripts under each lab's solutions/ already do that.

Run it two ways:

    python3 tests/test_flags.py          # standalone: prints a table, exits 1 on any failure
    pytest  tests/test_flags.py          # one parametrized case per flag

Config via env:
    SIXS_VERIFIER_URL   default http://localhost:8099
    SIXS_FLAG_IDS       optional comma-list to restrict which ids run
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

VERIFIER_URL = os.environ.get("SIXS_VERIFIER_URL", "http://localhost:8099").rstrip("/")
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PANEL_HTML = os.path.join(REPO, "flag-console", "index.html")

FLAG_RE = re.compile(r"FLAG\{[^}\s]*\}")

# Each entry: id -> how to recover the ground-truth flag from its container.
#   svc  : substring that uniquely matches the hosting container's name
#   root : docker exec as uid 0 (needed for 0600/0400 files and some envs)
#   cmd  : sh -c script whose stdout contains the flag
#   pat  : regex the recovered value must match (also disambiguates when a
#          command dumps more than one flag, e.g. a full /proc environ sweep)
FLAGS = {
    # ---- Lab 1: whitebox suite (snipvault / reportsmith / atlas) ----
    "l1-snip-1":  dict(svc="snipvault",   cmd="cat /opt/snipvault/config.ini",       pat=r"FLAG\{snipvault_file_read_[0-9a-f]+\}"),
    "l1-snip-2":  dict(svc="snipvault",   cmd="cat /home/snipvault/flag2.txt",       pat=r"FLAG\{snipvault_pickle_rce_[0-9a-f]+\}"),
    "l1-rs-1":    dict(svc="reportsmith", cmd="cat /opt/reportsmith/diag.key",       pat=r"FLAG\{reportsmith_pollution_[0-9a-f]+\}"),
    "l1-rs-2":    dict(svc="reportsmith", cmd="cat /home/node/flag_reportsmith.txt", pat=r"FLAG\{reportsmith_ejs_rce_[0-9a-f]+\}"),
    "l1-atlas-1": dict(svc="atlas-db",    cmd="psql -At -U \"$POSTGRES_USER\" -d atlas -c \"SELECT api_key FROM users WHERE username='admin'\"", pat=r"FLAG\{atlas_admin_[0-9a-f]+\}"),
    "l1-atlas-2": dict(svc="atlas-db",    cmd="psql -At -U \"$POSTGRES_USER\" -d atlas -c \"SELECT note FROM ops_notes WHERE note LIKE 'FLAG{%' LIMIT 1\"", pat=r"FLAG\{atlas_blind_[0-9a-f]+\}"),
    # env-only flag: reachable only through command execution in the DB
    "l1-atlas-3": dict(svc="atlas-db",    cmd="psql -At -U \"$POSTGRES_USER\" -d atlas -c \"CREATE TEMP TABLE _e(v text); COPY _e FROM PROGRAM 'printenv ATLAS_DB_FLAG'; SELECT v FROM _e;\"", pat=r"FLAG\{atlas_rce_[0-9a-f]+\}"),

    # ---- Lab 2: whitebox suite (printbay / caseforge / fleetledger) ----
    "l2-pb-1": dict(svc="printbay",       cmd="php -r '$d=new PDO(\"sqlite:/opt/printbay/printbay.db\");echo $d->query(\"SELECT value FROM settings WHERE key=\\\"ops_banner\\\"\")->fetchColumn();'", pat=r"FLAG\{printbay_leak_[0-9a-f]+\}"),
    "l2-pb-2": dict(svc="printbay", root=True, cmd="cat /opt/printbay/flag_chain.txt",      pat=r"FLAG\{printbay_chain_[0-9a-f]+\}"),
    "l2-pb-3": dict(svc="printbay", root=True, cmd="cat /opt/printbay/flag3_config.php",    pat=r"FLAG\{printbay_eval_[0-9a-f]+\}"),
    "l2-cf-1": dict(svc="caseforge",      cmd="python3 -c \"import sqlite3;print(sqlite3.connect('/opt/caseforge/caseforge.db').execute(\\\"SELECT value FROM settings WHERE key='motd'\\\").fetchone()[0])\"", pat=r"FLAG\{caseforge_prng_[0-9a-f]+\}"),
    "l2-cf-2": dict(svc="caseforge", root=True, cmd="cat /opt/caseforge/flag_ssti.txt",     pat=r"FLAG\{caseforge_ssti_[0-9a-f]+\}"),
    "l2-fl-1": dict(svc="fleetledger-db", cmd="psql -At -U \"$POSTGRES_USER\" -d fleet -c \"SELECT value FROM settings WHERE key='console_banner'\"", pat=r"FLAG\{fleetledger_union_[0-9a-f]+\}"),
    "l2-fl-2": dict(svc="fleetledger-db", cmd="psql -At -U \"$POSTGRES_USER\" -d fleet -c \"SELECT note FROM maintenance_notes WHERE note LIKE 'FLAG{%' LIMIT 1\"", pat=r"FLAG\{fleetledger_blind_[0-9a-f]+\}"),
    "l2-fl-3": dict(svc="fleetledger-db", cmd="psql -At -U \"$POSTGRES_USER\" -d fleet -c \"CREATE TEMP TABLE _e(v text); COPY _e FROM PROGRAM 'printenv FLEET_DB_FLAG'; SELECT v FROM _e;\"", pat=r"FLAG\{fleetledger_udf_[0-9a-f]+\}"),

    # ---- Lab 3: papertrail (+ internal intranet) ----
    # l3-1 lives only in the gunicorn PID 1 environ; readable by its own
    # (default exec) user but not by uid 0 under this daemon's userns.
    "l3-1": dict(svc="papertrail",        cmd="tr '\\0' '\\n' < /proc/1/environ",            pat=r"FLAG\{papertrail_prng_[0-9a-f]+\}"),
    "l3-2": dict(svc="intranet", root=True, cmd="for e in /proc/[0-9]*/environ; do tr '\\0' '\\n' < $e 2>/dev/null; done", pat=r"FLAG\{intranet_ssrf_[0-9a-f]+\}"),
    "l3-3": dict(svc="intranet", root=True, cmd="cat /opt/intranet/flag_seal.txt",           pat=r"FLAG\{intranet_rce_[0-9a-f]+\}"),

    # ---- Lab 4: harbordock (+ dockops console) ----
    "l4-1": dict(svc="harbordock-db",     cmd="psql -At -U postgres -d harbordock -c \"SELECT note FROM system_notes WHERE note LIKE 'FLAG{%' LIMIT 1\"", pat=r"FLAG\{harbordock_sqli_[0-9a-f]+\}"),
    "l4-2": dict(svc="harbordock-db",     cmd="psql -At -U postgres -d harbordock -c \"SELECT value FROM token_vault WHERE label='seal'\"", pat=r"FLAG\{harbordock_vault_[0-9a-f]+\}"),
    "l4-3": dict(svc="dockops", root=True, cmd="cat /opt/dockops/flag_console.txt",          pat=r"FLAG\{dockops_rce_[0-9a-f]+\}"),

    # ---- Lab 5: tidegate (fused chain) ----
    # l5-1 is a DB row reachable only through the tracking oracle's blind
    # SQLi; l5-2 is the web-readable LFI target; l5-3 is the root-only seal.
    "l5-1": dict(svc="tidegate", cmd="php -r \"echo (new PDO('sqlite:/opt/tidegate/tidegate.db'))->query(\\\"SELECT v FROM ops_secrets WHERE k='gateway_seal'\\\")->fetchColumn();\"", pat=r"FLAG\{tidegate_sqli_[0-9a-f]+\}"),
    "l5-2": dict(svc="tidegate", cmd="cat /opt/tidegate/flag_manifest.txt",                  pat=r"FLAG\{tidegate_xxe_[0-9a-f]+\}"),
    "l5-3": dict(svc="tidegate", root=True, cmd="cat /opt/tidegate/flag_seal.txt",           pat=r"FLAG\{tidegate_rce_[0-9a-f]+\}"),
}


class FlagError(Exception):
    pass


def resolve_container(svc):
    out = subprocess.run(
        ["docker", "ps", "--filter", f"name={svc}", "--format", "{{.Names}}"],
        capture_output=True, text=True,
    ).stdout.split()
    if not out:
        raise FlagError(f"no running container matches name~={svc!r}")
    if len(out) > 1:
        raise FlagError(f"name~={svc!r} is ambiguous: {out}")
    return out[0]


def extract(fid):
    """Return the ground-truth flag value read from the hosting container."""
    spec = FLAGS[fid]
    cont = resolve_container(spec["svc"])
    argv = ["docker", "exec"]
    if spec.get("root"):
        argv += ["-u", "0"]
    argv += [cont, "sh", "-c", spec["cmd"]]
    res = subprocess.run(argv, capture_output=True, text=True, timeout=30)
    blob = res.stdout + res.stderr
    pat = re.compile(spec["pat"])
    m = pat.search(blob)
    if not m:
        snippet = blob.strip().replace("\n", " ")[:200]
        raise FlagError(f"{fid}: value matching /{spec['pat']}/ not found in {cont} "
                        f"(exit {res.returncode}): {snippet!r}")
    return m.group(0)


def verify(fid, flag):
    """Submit (id, flag) to the panel's verify oracle; return parsed JSON."""
    body = json.dumps({"id": fid, "flag": flag}).encode()
    req = urllib.request.Request(
        f"{VERIFIER_URL}/verify", data=body,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def health():
    with urllib.request.urlopen(f"{VERIFIER_URL}/health", timeout=10) as r:
        return json.loads(r.read())


def panel_ids():
    """Flag ids the console (index.html) advertises, if the file is present."""
    try:
        with open(PANEL_HTML, encoding="utf-8") as f:
            html = f.read()
    except OSError:
        return None
    return set(re.findall(r"\bl[1-5]-[a-z0-9-]+\b", html))


def check_one(fid):
    """Full container+panel assertion for a single flag id. Raises FlagError."""
    value = extract(fid)                      # container side
    good = verify(fid, value)                 # panel side (real)
    if not good.get("ok") or not good.get("known"):
        raise FlagError(f"{fid}: panel rejected the real flag {value}: {good}")
    tampered = "FLAG{tampered}"
    bad = verify(fid, tampered)               # panel side (negative)
    if bad.get("ok"):
        raise FlagError(f"{fid}: panel accepted a tampered flag: {bad}")
    return value


# --------------------------------------------------------------------------
# pytest entrypoints (only if pytest is installed; the module also runs solo)
# --------------------------------------------------------------------------
try:
    import pytest

    @pytest.fixture(scope="session")
    def _health():
        return health()

    def test_health(_health):
        assert _health.get("ok") is True
        assert _health.get("flags") == len(FLAGS), \
            f"panel reports {_health.get('flags')} hashes; registry has {len(FLAGS)}"

    def test_panel_ids_match_registry():
        ids = panel_ids()
        if ids is None:
            pytest.skip("flag-console/index.html not found")
        assert ids == set(FLAGS), f"panel vs registry mismatch: {ids ^ set(FLAGS)}"

    def test_unknown_id_is_unknown():
        assert verify("definitely-not-a-flag-id", "FLAG{x}").get("known") is False

    @pytest.mark.parametrize("fid", sorted(FLAGS))
    def test_flag(fid):
        check_one(fid)

except ImportError:
    pass


# --------------------------------------------------------------------------
# Standalone runner
# --------------------------------------------------------------------------
def main():
    only = os.environ.get("SIXS_FLAG_IDS")
    ids = [i.strip() for i in only.split(",")] if only else sorted(FLAGS)

    print(f"verifier : {VERIFIER_URL}")
    try:
        h = health()
        print(f"health   : ok={h.get('ok')} flags={h.get('flags')} (registry={len(FLAGS)})")
    except Exception as e:
        print(f"health   : UNREACHABLE ({e})")
        return 2

    pids = panel_ids()
    if pids is not None and pids != set(FLAGS):
        print(f"panel ids: MISMATCH vs registry -> {sorted(pids ^ set(FLAGS))}")
    else:
        print("panel ids: match registry" if pids is not None else "panel ids: (index.html not found)")
    print("-" * 72)

    failures = []
    for fid in ids:
        try:
            value = check_one(fid)
            print(f"  PASS  {fid:<16} {value}")
        except Exception as e:
            failures.append(fid)
            print(f"  FAIL  {fid:<16} {e}")

    print("-" * 72)
    print(f"{len(ids) - len(failures)}/{len(ids)} flags verified on container + panel")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
