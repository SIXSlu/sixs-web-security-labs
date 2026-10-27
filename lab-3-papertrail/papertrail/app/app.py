"""PaperTrail document portal - the public face of the harbour's paper mill."""
import re
import urllib.parse
import urllib.request

from flask import Flask, jsonify, render_template_string, request, session

import db
import magiclink

app = Flask(__name__)
app.secret_key = magiclink.session_secret()

db.init_db()

LOGIN_PAGE = """
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>PaperTrail sign-in</title>
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
<nav class="sx-nav"><a class="sx-brand" href="#"><span class="mark">SX</span> SIXS&nbsp;Labs</a><a class="sx-app" href="/">PaperTrail</a><span class="sx-tag">harbour portal</span></nav>
<main>
<h1>PaperTrail</h1>
<div class="card" style="max-width:28rem">
<p>We removed passwords. Enter your address and the mail worker drops a
sign-in link, good for ten minutes.</p>
<form method="post" action="/auth/request-link">
  <label>Work email <input name="email" placeholder="you@papertrail.internal"></label>
  <button>Send me a link</button>
</form>
{% if queued %}<p class="note">Queued as mail job #{{ queued }}.</p>{% endif %}
</div>
</main>
<footer class="sx-foot"><span class="mark">SX</span> A SIXS security training lab <span>·</span> no packets were harmed in the making of this lab (a few got definetly roughed up)</footer>
</body></html>
"""

ADMIN_PAGE = """
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>PaperTrail admin</title>
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
<nav class="sx-nav"><a class="sx-brand" href="#"><span class="mark">SX</span> SIXS&nbsp;Labs</a><a class="sx-app" href="/">PaperTrail</a><span class="sx-tag">harbour ops</span></nav>
<main>
<h1>Harbour Ops — admin desk</h1>
<h2>Documents</h2>
{% for d in docs %}
  <article><h3>{{ d.title }}</h3><pre>{{ d.body }}</pre></article>
{% endfor %}
<h2>Link inspector</h2>
<div class="card">
<p>Point the inspector at any http(s) URL to see what a link opens as
before the staff newsletter quotes it.</p>
<form method="post" action="/admin/inspect">
  <label>URL <input name="url" placeholder="https://..."></label>
  <button>Inspect</button>
</form>
{% if inspected %}
  <h3>Inspector result ({{ inspected.status }})</h3>
  <pre>{{ inspected.excerpt }}</pre>
{% endif %}
</div>
</main>
<footer class="sx-foot"><span class="mark">SX</span> A SIXS security training lab <span>·</span> no packets were harmed in the making of this lab (a few got definetly roughed up)</footer>
</body></html>
"""


@app.route("/")
def login_page():
    return render_template_string(LOGIN_PAGE, queued=0)


@app.route("/auth/request-link", methods=["POST"])
def request_link():
    email = (request.form.get("email")
             or (request.get_json(silent=True) or {}).get("email", "")).strip()
    if not email:
        return jsonify(error="email is required"), 400
    # Any address is fine; the link goes to the mail worker either way.
    job, _ = magiclink.issue_link(email)
    return render_template_string(LOGIN_PAGE, queued=job)


@app.route("/magic/<token>")
def magic_login(token):
    email = magiclink.consume_token(token)
    if email is None:
        return "This sign-in link is unknown, used or expired.", 400
    session["email"] = email
    row = db.user_role(email)
    session["role"] = row or "staff"
    return f"Signed in as {email}. Welcome back to PaperTrail."


@app.route("/admin")
def admin_desk():
    if session.get("role") != "admin":
        return "Admin desk is for admins.", 403
    docs = db.documents_for("admin@papertrail.internal")
    return render_template_string(ADMIN_PAGE, docs=docs, inspected=None)


@app.route("/admin/inspect", methods=["POST"])
def admin_inspect():
    if session.get("role") != "admin":
        return "Admin desk is for admins.", 403
    url = (request.form.get("url") or request.json.get("url", "")).strip()

    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ("http", "https"):
        return "Only http(s) URLs survive the inspector.", 400

    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            body = resp.read(4096).decode(errors="replace")
    except Exception as exc:  # inspector is a read-only tool: never crash
        return f"Inspector could not reach it: {exc}", 502

    title = re.search(r"<title>(.*?)</title>", body, re.S | re.I)
    excerpt = (title.group(1).strip() + "\n\n" if title else "") + body
    return render_template_string(
        ADMIN_PAGE,
        docs=db.documents_for("admin@papertrail.internal"),
        inspected={"status": "reached", "excerpt": excerpt},
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)