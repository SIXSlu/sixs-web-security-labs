#!/usr/bin/env python3
"""CaseForge - internal IT support ticket desk.

Staff sign in with passwordless magic links: the desk mails a one-time
token to the staff email address, the token is validated on this
service. Customer reply templates live in the database and admins can
edit and preview them from the dashboard before they go out with the
next ticket notification batch.
"""

import os
import time

import jinja2
from flask import (Flask, abort, redirect, render_template, request,
                   session, url_for)

from db import db, init_db
from magiclink import generate_token

TOKEN_TTL = 15 * 60

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ["CASEFORGE_SECRET_KEY"]


# --------------------------------------------------------------------------
# auth helpers
# --------------------------------------------------------------------------
def current_user():
    uid = session.get("uid")
    if uid is None:
        return None
    with db() as conn:
        return conn.execute(
            "SELECT * FROM users WHERE id = ?", (uid,)).fetchone()


def require_admin():
    user = current_user()
    if user is None or user["role"] != "admin":
        abort(403, "admin only")
    return user


# --------------------------------------------------------------------------
# magic-link login
# --------------------------------------------------------------------------
@app.route("/")
def index():
    if current_user():
        return redirect(url_for("admin_dashboard"))
    return redirect(url_for("login_page"))


@app.route("/login", methods=["GET"])
def login_page():
    return render_template("login.html", sent=request.args.get("sent"))


@app.route("/api/auth/magic", methods=["POST"])
def magic_request():
    """Create a sign-in token and hand it to the mail relay.

    Accepts the helpdesk web form as well as the field techs' CLI
    (which posts JSON), hence the two content types.
    """
    if request.is_json:
        email = (request.get_json(silent=True) or {}).get("email", "")
    else:
        email = request.form.get("email", "")
    email = email.strip().lower()

    with db() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE email = ?", (email,)).fetchone()

    if row is not None:
        token = generate_token()
        with db() as conn:
            conn.execute(
                "INSERT INTO magic_tokens (token, user_id, expires_at) "
                "VALUES (?, ?, ?)",
                (token, row["id"], int(time.time()) + TOKEN_TTL))
        # mail relay is async - the token is logged for the relay worker
        link = request.host_url + "api/auth/magic/verify?token=" + token
        app.logger.info("mail relay -> %s : %s", email, link)

    # answer the same whether or not the address is known (no enumeration)
    if request.is_json:
        return {"status": "sent", "message": "check your inbox"}
    return redirect(url_for("login_page", sent=1))


def _verify_token(token):
    """Return the user row for a valid unused token, else None."""
    with db() as conn:
        row = conn.execute(
            "SELECT t.*, u.id AS uid FROM magic_tokens t "
            "JOIN users u ON u.id = t.user_id "
            "WHERE t.token = ? AND t.used = 0 AND t.expires_at > ?",
            (token, int(time.time()))).fetchone()
        if row is None:
            return None
        # one-time: burn the token as soon as it is accepted
        conn.execute("UPDATE magic_tokens SET used = 1 WHERE token = ?",
                     (token,))
    with db() as conn:
        return conn.execute(
            "SELECT * FROM users WHERE id = ?", (row["uid"],)).fetchone()


@app.route("/api/auth/magic/verify", methods=["GET", "POST"])
def magic_verify():
    if request.method == "GET":
        token = request.args.get("token", "")
    else:
        token = ((request.get_json(silent=True) or {}).get("token", "")
                 if request.is_json else request.form.get("token", ""))
    token = token.strip().lower()

    user = _verify_token(token)
    if user is None:
        if request.method == "GET":
            abort(400, "invalid or expired link")
        return {"status": "denied", "message": "invalid or expired link"}, 400

    session["uid"] = user["id"]
    if request.method == "GET":
        return redirect(url_for("admin_dashboard"))
    return {"status": "authenticated", "user": user["email"],
            "role": user["role"]}


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login_page"))


# --------------------------------------------------------------------------
# admin dashboard and template editor
# --------------------------------------------------------------------------
@app.route("/admin")
def admin_dashboard():
    user = require_admin()
    with db() as conn:
        motd = conn.execute(
            "SELECT value FROM settings WHERE key = 'motd'").fetchone()
        templates = conn.execute(
            "SELECT id, name FROM templates ORDER BY id").fetchall()
    return render_template("admin.html", user=user,
                           motd=motd["value"] if motd else "",
                           templates=templates)


@app.route("/admin/templates/<int:tid>", methods=["GET", "POST"])
def template_editor(tid):
    require_admin()
    with db() as conn:
        tpl = conn.execute(
            "SELECT * FROM templates WHERE id = ?", (tid,)).fetchone()
        if tpl is None:
            abort(404, "no such template")
        if request.method == "POST":
            body = request.form.get("body", "")
            conn.execute("UPDATE templates SET body = ? WHERE id = ?",
                         (body, tid))
            tpl = conn.execute(
                "SELECT * FROM templates WHERE id = ?", (tid,)).fetchone()
    return render_template("editor.html", tpl=tpl)


@app.route("/admin/templates/<int:tid>/preview", methods=["POST"])
def template_preview(tid):
    """Render the stored template body the way the mail batch will."""
    require_admin()
    with db() as conn:
        tpl = conn.execute(
            "SELECT body FROM templates WHERE id = ?", (tid,)).fetchone()
    if tpl is None:
        abort(404, "no such template")

    body = tpl["body"]
    # Sec review 2025-11: template bodies are rendered with real ticket
    # data before being emailed, so kill the obvious injection tricks
    # up front: dots (include paths / traversal) and underscores (dunder
    # attribute access). Keep it simple - no regexes, no allowlist.
    body = body.replace(".", "").replace("_", "")

    rendered = jinja2.Template(body).render()
    return render_template("editor.html", tpl={"id": tid, "name": "",
                                               "body": tpl["body"]},
                           preview=rendered)


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)