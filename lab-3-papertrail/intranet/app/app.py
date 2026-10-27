"""PaperTrail intranet - operations notes, only reachable from the
harbour's internal network.

Everything here assumes the network does the gating: the portal and
this CMS are the only two hosts on that segment, so whoever arrives
via the portal already cleared the front door.
"""
import ipaddress
import os

import jinja2
from flask import Flask, abort, render_template_string, request

app = Flask(__name__)

DASHBOARD = """
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>PaperTrail intranet</title>
<style>
:root{--ink:#f1f3f5;--muted:#8a9199;--line:rgba(255,255,255,.1)}
*{box-sizing:border-box}
body{margin:0;font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;line-height:1.6;color:var(--ink);background:#050607;background-image:linear-gradient(rgba(255,255,255,.05) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.05) 1px,transparent 1px);background-size:46px 46px;background-attachment:fixed;min-height:100vh}
.sx-nav{display:flex;align-items:center;gap:1rem;flex-wrap:wrap;padding:.7rem 1.2rem;border-bottom:1px solid var(--line);background:rgba(5,6,7,.85);position:sticky;top:0}
.sx-brand{display:inline-flex;align-items:center;gap:.5rem;font-weight:700;letter-spacing:.14em;text-transform:uppercase;font-size:.8rem;color:#fff;text-decoration:none}
.sx-brand .mark{display:inline-grid;place-items:center;width:22px;height:22px;background:#f1f3f5;color:#050607;font-weight:800;font-size:.58rem;border-radius:4px}
.sx-app{padding-left:1rem;border-left:1px solid var(--line);font-weight:600;color:#fff;text-decoration:none}
.sx-tag{font-family:ui-monospace,Menlo,monospace;font-size:.64rem;letter-spacing:.08em;text-transform:uppercase;color:#5a616a;border:1px solid var(--line);border-radius:999px;padding:.1rem .5rem}
main{max-width:860px;margin:2.2rem auto;padding:0 1.2rem}
h1{font-size:1.7rem;margin:.2rem 0 1rem}h2{font-size:1.15rem;margin:1.8rem 0 .7rem}h3{margin:.2rem 0}
.card,article{display:block;background:linear-gradient(180deg,#121418,#0c0e11);border:1px solid var(--line);border-radius:10px;padding:1.1rem 1.3rem;margin:1rem 0}
label{display:block;color:var(--muted);font-size:.85rem;margin:.6rem 0 .25rem}
input,textarea,select{width:100%;font:inherit;color:var(--ink);background:#0c0e11;border:1px solid rgba(255,255,255,.16);border-radius:8px;padding:.55rem .7rem;margin:.25rem 0}
input:focus,textarea:focus{outline:none;border-color:rgba(255,255,255,.5);box-shadow:0 0 0 3px rgba(255,255,255,.08)}
button{font:inherit;font-weight:600;cursor:pointer;background:#f1f3f5;color:#050607;border:none;border-radius:8px;padding:.55rem 1.1rem;margin-top:.5rem}
button:hover{opacity:.85}
pre{background:#0c0e11;border:1px solid var(--line);border-radius:8px;padding:1rem;overflow:auto;white-space:pre-wrap}
code{font-family:ui-monospace,Menlo,monospace;background:#171a1f;border:1px solid var(--line);padding:.08rem .35rem;border-radius:5px}
a{color:#fff;text-underline-offset:3px}
.sx-foot{max-width:860px;margin:3rem auto 2rem;padding:1.2rem 1.2rem 0;border-top:1px solid var(--line);color:#5a616a;font-size:.8rem;display:flex;gap:.5rem;align-items:center;flex-wrap:wrap}
.sx-foot .mark{display:inline-grid;place-items:center;width:18px;height:18px;background:#f1f3f5;color:#050607;font-weight:800;font-size:.55rem;border-radius:3px}
.sx-foot a{color:#8a9199;text-decoration:none}.sx-foot a:hover{color:#fff}
</style>
</head>
<body>
<nav class="sx-nav"><a class="sx-brand" href="#"><span class="mark">SX</span> SIXS&nbsp;Labs</a><a class="sx-app" href="/">PaperTrail Intranet</a><span class="sx-tag">internal segment</span></nav>
<main>
<h1>Intranet operations board</h1>
<div class="card">
<p>You are on the internal segment (<code>{{ remote }}</code>). Staff note of the day:</p>
<pre>{{ flag_note }}</pre>
<p><a href="/notes/render?doc=intro">Notes renderer</a> — render a note
body before it goes on the board.</p>
</div>
</main>
<footer class="sx-foot"><span class="mark">SX</span> A SIXS security training lab <span>·</span> no packets were harmed in the making of this lab (a few got definetly roughed up)</footer>
</body></html>
"""

RENDER_PAGE = """
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Note renderer</title>
<style>
:root{--ink:#f1f3f5;--muted:#8a9199;--line:rgba(255,255,255,.1)}
*{box-sizing:border-box}
body{margin:0;font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;line-height:1.6;color:var(--ink);background:#050607;background-image:linear-gradient(rgba(255,255,255,.05) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.05) 1px,transparent 1px);background-size:46px 46px;background-attachment:fixed;min-height:100vh}
.sx-nav{display:flex;align-items:center;gap:1rem;flex-wrap:wrap;padding:.7rem 1.2rem;border-bottom:1px solid var(--line);background:rgba(5,6,7,.85);position:sticky;top:0}
.sx-brand{display:inline-flex;align-items:center;gap:.5rem;font-weight:700;letter-spacing:.14em;text-transform:uppercase;font-size:.8rem;color:#fff;text-decoration:none}
.sx-brand .mark{display:inline-grid;place-items:center;width:22px;height:22px;background:#f1f3f5;color:#050607;font-weight:800;font-size:.58rem;border-radius:4px}
.sx-app{padding-left:1rem;border-left:1px solid var(--line);font-weight:600;color:#fff;text-decoration:none}
.sx-tag{font-family:ui-monospace,Menlo,monospace;font-size:.64rem;letter-spacing:.08em;text-transform:uppercase;color:#5a616a;border:1px solid var(--line);border-radius:999px;padding:.1rem .5rem}
main{max-width:860px;margin:2.2rem auto;padding:0 1.2rem}
h1{font-size:1.7rem;margin:.2rem 0 1rem}h2{font-size:1.15rem;margin:1.8rem 0 .7rem}h3{margin:.2rem 0}
.card,article{display:block;background:linear-gradient(180deg,#121418,#0c0e11);border:1px solid var(--line);border-radius:10px;padding:1.1rem 1.3rem;margin:1rem 0}
label{display:block;color:var(--muted);font-size:.85rem;margin:.6rem 0 .25rem}
input,textarea,select{width:100%;font:inherit;color:var(--ink);background:#0c0e11;border:1px solid rgba(255,255,255,.16);border-radius:8px;padding:.55rem .7rem;margin:.25rem 0}
input:focus,textarea:focus{outline:none;border-color:rgba(255,255,255,.5);box-shadow:0 0 0 3px rgba(255,255,255,.08)}
button{font:inherit;font-weight:600;cursor:pointer;background:#f1f3f5;color:#050607;border:none;border-radius:8px;padding:.55rem 1.1rem;margin-top:.5rem}
button:hover{opacity:.85}
pre{background:#0c0e11;border:1px solid var(--line);border-radius:8px;padding:1rem;overflow:auto;white-space:pre-wrap}
code{font-family:ui-monospace,Menlo,monospace;background:#171a1f;border:1px solid var(--line);padding:.08rem .35rem;border-radius:5px}
a{color:#fff;text-underline-offset:3px}
.sx-foot{max-width:860px;margin:3rem auto 2rem;padding:1.2rem 1.2rem 0;border-top:1px solid var(--line);color:#5a616a;font-size:.8rem;display:flex;gap:.5rem;align-items:center;flex-wrap:wrap}
.sx-foot .mark{display:inline-grid;place-items:center;width:18px;height:18px;background:#f1f3f5;color:#050607;font-weight:800;font-size:.55rem;border-radius:3px}
.sx-foot a{color:#8a9199;text-decoration:none}.sx-foot a:hover{color:#fff}
</style>
</head>
<body>
<nav class="sx-nav"><a class="sx-brand" href="#"><span class="mark">SX</span> SIXS&nbsp;Labs</a><a class="sx-app" href="/">PaperTrail Intranet</a><span class="sx-tag">note renderer</span></nav>
<main>
<h1>Rendered note</h1>
<pre class="card">{{ rendered }}</pre>
</main>
<footer class="sx-foot"><span class="mark">SX</span> A SIXS security training lab <span>·</span> no packets were harmed in the making of this lab (a few got definetly roughed up)</footer>
</body></html>
"""


def internal_only():
    remote = request.remote_addr or ""
    try:
        if ipaddress.ip_address(remote).is_private:
            return
    except ValueError:
        pass
    abort(403)


@app.route("/")
def dashboard():
    internal_only()
    return render_template_string(
        DASHBOARD,
        remote=request.remote_addr,
        flag_note=os.environ.get("INTRANET_FLAG2", "FLAG{intranet_unset_2}"),
    )


@app.route("/health")
def health():
    return "intranet up; see /notes/render for the note tool"


@app.route("/notes/render", methods=["GET"])
def notes_render():
    internal_only()
    doc = request.args.get("doc", "")
    rendered = jinja2.Template(
        f"<h2>{sanitize_note(doc)}</h2>"
    ).render()
    return render_template_string(RENDER_PAGE, rendered=rendered)


def sanitize_note(doc):
    """June review fix: no dunder attribute names in rendered notes.

    The prior portal had a template escape-string bypass ('\\x5f...'),
    so this one kills the escape characters as well - an escaped name
    has no way to survive this pair, and a dunder can never be spelled.
    """
    while "__" in doc:
        doc = doc.replace("__", "", 1)
    doc = doc.replace("\\", "")
    return doc


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)