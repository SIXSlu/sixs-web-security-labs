"""SQLite storage for CaseForge: users, magic links and email templates."""

import os
import sqlite3

APP_ROOT = os.environ.get("CASEFORGE_ROOT", "/opt/caseforge")
DB_FILE = os.path.join(APP_ROOT, "caseforge.db")

SEED_USERS = [
    ("admin@caseforge.internal", "Ops Admin", "admin"),
    ("tech@caseforge.internal", "Tier-1 Tech", "tech"),
]

SEED_TEMPLATES = [
    (
        "ticket-welcome",
        "Hi {{customer_name}},\n\n"
        "we received your ticket #{{ticket_id}} and the helpdesk will get\n"
        "back to you within our SLA window.\n\n"
        "Kind regards,\n"
        "the CaseForge support desk",
    ),
    (
        "ticket-escalated",
        "Hi {{customer_name}},\n\n"
        "your ticket #{{ticket_id}} was escalated to a senior engineer.\n\n"
        "Kind regards,\n"
        "the CaseForge support desk",
    ),
]


def db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Create the schema on first boot and seed the desk data.

    The `settings` table is normally pre-created by the deployment
    provisioning step (it carries the MOTD banner), but we make sure it
    exists here too so a fresh checkout boots cleanly.
    """
    with db() as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'tech')""")

        conn.execute("""CREATE TABLE IF NOT EXISTS magic_tokens (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            used INTEGER NOT NULL DEFAULT 0)""")

        conn.execute("""CREATE TABLE IF NOT EXISTS templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            body TEXT NOT NULL)""")

        conn.execute("""CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL)""")

        if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
            for email, name, role in SEED_USERS:
                conn.execute(
                    "INSERT INTO users (email, name, role) VALUES (?, ?, ?)",
                    (email, name, role))

        if conn.execute("SELECT COUNT(*) FROM templates").fetchone()[0] == 0:
            for name, body in SEED_TEMPLATES:
                conn.execute(
                    "INSERT INTO templates (name, body) VALUES (?, ?)",
                    (name, body))