"""Seed data for the PaperTrail document portal."""
import os
import sqlite3

DB_PATH = "/opt/papertrail/papertrail.db"

# Demo tenants so the portal does not look empty on a fresh install.
# The admin brief is deliberately in the documents table: that is the
# thing you are supposed to reach with an admin session, and it is the
# reason the whole sign-in flow exists.
DOCUMENTS = [
    ("admin@papertrail.internal", "Harbour Works status brief",
     os.environ.get("PAPERTRAIL_FLAG1", "FLAG{papertrail_unset_1}")),
    ("admin@papertrail.internal", "2027 berth pricing draft",
     "Q1 occupancy is at 78%, berth fees flat, crane rental up 4%."),
    ("dockmaster@papertrail.internal", "Dredging rotation",
     "Trailing suction hopper every second Thursday, 0600-1100."),
    ("intern@papertrail.internal", "Onboarding checklist",
     "Badge photo, safety induction, lanyard, canteen card."),
    ("intern@papertrail.internal", "Fender inspection rota",
     "North quay fenders D3 and D7 flagged, replace before storm season."),
]


def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            email TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            display_name TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS magic_links (
            token TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            expires REAL NOT NULL,
            used INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    conn.execute("DELETE FROM users")
    conn.execute("DELETE FROM documents")
    conn.execute("DELETE FROM magic_links")
    conn.executemany(
        "INSERT INTO users (email, role, display_name) VALUES (?, ?, ?)",
        [
            ("admin@papertrail.internal", "admin", "Harbour Ops Admin"),
            ("dockmaster@papertrail.internal", "staff", "Dock Master"),
            ("intern@papertrail.internal", "staff", "Rotating Intern"),
        ],
    )
    conn.executemany(
        "INSERT INTO documents (owner, title, body) VALUES (?, ?, ?)",
        DOCUMENTS,
    )
    conn.commit()
    conn.close()


def user_role(email):
    conn = sqlite3.connect(DB_PATH)
    row = conn.execute(
        "SELECT role FROM users WHERE email = ?", (email,)
    ).fetchone()
    conn.close()
    return row[0] if row else None


def documents_for(owner):
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute(
        "SELECT owner, title, body FROM documents WHERE owner = ?", (owner,)
    ).fetchall()
    conn.close()
    return [{"owner": o, "title": t, "body": b} for o, t, b in rows]