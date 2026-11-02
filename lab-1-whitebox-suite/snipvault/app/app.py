#!/usr/bin/env python3
"""SnipVault - team paste vault with data-file preview.

Sessions are stateless: the session object is pickled, base64-encoded and
signed with HMAC-SHA256 using the deployment key from config.ini. This
keeps the workers stateless (no redis dependency) which was a requirement
from the infra team.
"""

import base64
import configparser
import hashlib
import hmac
import os
import pickle
import sqlite3

from flask import Flask, abort, g, redirect, render_template, request, session, url_for

APP_ROOT = os.environ.get("SNIPVAULT_ROOT", "/opt/snipvault")
STORAGE_DIR = os.path.join(APP_ROOT, "data")
CONFIG_FILE = os.path.join(APP_ROOT, "config.ini")
DB_FILE = os.path.join(STORAGE_DIR, "snipvault.db")

_cfg = configparser.ConfigParser()
_cfg.read(CONFIG_FILE)
SECRET_KEY = _cfg["auth"]["secret_key"].encode()

app = Flask(__name__)


# --------------------------------------------------------------------------
# stateless signed-pickle sessions
# --------------------------------------------------------------------------
def make_token(sess_obj):
    payload = base64.b64encode(pickle.dumps(sess_obj))
    sig = hmac.new(SECRET_KEY, payload, hashlib.sha256).hexdigest()
    return payload.decode() + "." + sig


def read_token(token):
    """Verify signature and unpickle the session object."""
    try:
        payload, sig = token.split(b".", 1)
    except ValueError:
        return None
    expected = hmac.new(SECRET_KEY, payload, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig.decode(errors="replace"), expected):
        return None
    try:
        return pickle.loads(base64.b64decode(payload))
    except Exception:
        return None


@app.before_request
def load_session():
    g.user = None
    token = request.cookies.get("sv_token", "")
    if token:
        sess_obj = read_token(token.encode())
        if isinstance(sess_obj, dict) and "uid" in sess_obj:
            g.user = sess_obj


def require_user():
    if g.user is None:
        abort(401, "login required")
    return g.user


# --------------------------------------------------------------------------
# storage
# --------------------------------------------------------------------------
def db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def pw_hash(password, salt):
    return hashlib.sha256((salt + password).encode()).hexdigest()


def init_db():
    os.makedirs(STORAGE_DIR, exist_ok=True)
    with db() as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            salt TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            note TEXT DEFAULT '')""")


# --------------------------------------------------------------------------
# routes
# --------------------------------------------------------------------------
@app.route("/")
def index():
    if g.user:
        return redirect(url_for("account"))
    return redirect(url_for("login_page"))


@app.route("/login", methods=["GET", "POST"])
def login_page():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        with db() as conn:
            row = conn.execute(
                "SELECT * FROM users WHERE username = ?", (username,)
            ).fetchone()
        if row and row["password_hash"] == pw_hash(password, row["salt"]):
            resp = redirect(url_for("account"))
            resp.set_cookie(
                "sv_token", make_token({"uid": row["id"], "username": row["username"]})
            )
            return resp
        error = "invalid credentials"
    return render_template("login.html", error=error)


@app.route("/register", methods=["GET", "POST"])
def register_page():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        if not username or not password:
            error = "username and password required"
        else:
            import secrets

            salt = secrets.token_hex(4)
            try:
                with db() as conn:
                    conn.execute(
                        "INSERT INTO users (username, salt, password_hash) "
                        "VALUES (?, ?, ?)",
                        (username, salt, pw_hash(password, salt)),
                    )
                return redirect(url_for("login_page"))
            except sqlite3.IntegrityError:
                error = "username taken"
    return render_template("register.html", error=error)


@app.route("/logout")
def logout():
    resp = redirect(url_for("login_page"))
    resp.delete_cookie("sv_token")
    return resp


@app.route("/account")
def account():
    user = require_user()
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE id = ?", (user["uid"],)
        ).fetchone()
    return render_template(
        "account.html", username=row["username"], note=row["note"] or ""
    )


@app.route("/note", methods=["POST"])
def save_note():
    user = require_user()
    note = request.form.get("note", "")[:4000]
    with db() as conn:
        conn.execute("UPDATE users SET note = ? WHERE id = ?", (note, user["uid"]))
    return redirect(url_for("account"))


@app.route("/data/preview")
def preview():
    """Inline preview for data files the user stored in their vault dir.

    The path arrives base64-encoded because the frontend builds it from
    drag'n'dropped entries whose names sometimes contain characters that
    break query strings.
    """
    require_user()
    b64 = request.args.get("path", "")
    try:
        rel = base64.b64decode(b64).decode("utf-8", errors="replace")
    except Exception:
        abort(400, "path must be base64")

    # Vault files live under STORAGE_DIR; keep the path inside it.
    rel = rel.replace("../", "")
    if rel.startswith("/"):
        abort(400, "absolute paths are not supported")

    # Resolve what is left and keep it inside the application root. The
    # preview may still reach other files of this app (that is the
    # file-read bug this lab trains), but it must not be able to walk
    # out of /opt/snipvault into the wider filesystem.
    full = os.path.realpath(os.path.join(STORAGE_DIR, rel))
    root = os.path.realpath(APP_ROOT)
    if full != root and not full.startswith(root + os.sep):
        abort(400, "path escapes the app root")
    if not os.path.isfile(full):
        abort(404, "no such vault file")

    content = []
    with open(full, "r", errors="replace") as fh:
        for i, line in enumerate(fh):
            content.append(line)
            if i >= 199:
                break
    return render_template("preview.html", path=rel, content="".join(content))


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
