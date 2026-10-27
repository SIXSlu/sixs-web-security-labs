-- ATLAS registry bootstrap. Runs once when the data volume is empty.
-- NOTE: the atlas role intentionally owns everything and was granted
-- SUPERUSER by an old migration so the ops team could run pg_dump
-- locally; nobody ever removed it.

CREATE ROLE atlas LOGIN SUPERUSER PASSWORD 'atlas-dev-2026';
CREATE DATABASE atlas OWNER atlas;

\connect atlas

CREATE TABLE users (
    id            serial PRIMARY KEY,
    username      text UNIQUE NOT NULL,
    email         text UNIQUE NOT NULL,
    role          text NOT NULL DEFAULT 'user',
    salt          text NOT NULL,
    password_hash text NOT NULL,
    api_key       text NOT NULL
);

CREATE TABLE assets (
    id       serial PRIMARY KEY,
    name     text NOT NULL,
    category text NOT NULL,
    status   text NOT NULL DEFAULT 'active'
);

CREATE TABLE password_reset_tokens (
    id        serial PRIMARY KEY,
    email     text NOT NULL,
    token     text NOT NULL,
    expires_at timestamp NOT NULL
);

-- ops notes are kept out of the API on purpose; the runbook reference
-- implementation stores the weekly ops key here (see runbook section 4)
CREATE TABLE ops_notes (
    id   serial PRIMARY KEY,
    note text NOT NULL
);

-- NOTE (runbook): all seeded accounts still use the provisioning
-- password Init-Pass-2026 and are expected to change it on first login.
INSERT INTO users (username, email, role, salt, password_hash, api_key) VALUES
    ('admin',   'admin@nimbus.internal',   'admin', 'a7f3c9d1',
     'e8d7d0eba22133fb03b815d6a03784d65f1645676687bf33905693c260487504',
     'FLAG{atlas_admin_' || substr(md5(random()::text), 1, 12) || '}'),
    ('fleetops','fleetops@nimbus.internal', 'user',  'a7f3c9d1',
     'e8d7d0eba22133fb03b815d6a03784d65f1645676687bf33905693c260487504',
     'AK-7f21c9e0b4d8a2'),
    ('analyst', 'analyst@nimbus.internal',  'user',  'a7f3c9d1',
     'e8d7d0eba22133fb03b815d6a03784d65f1645676687bf33905693c260487504',
     'AK-3b84d1f6c0a9e5');

INSERT INTO assets (name, category, status) VALUES
    ('edge-router-01',   'network',  'active'),
    ('edge-router-02',   'network',  'active'),
    ('switch-core-01',   'network',  'maintenance'),
    ('srv-erp-01',       'server',   'active'),
    ('srv-erp-02',       'server',   'provisioning'),
    ('srv-files-01',     'server',   'active'),
    ('wks-lab-01',       'workstation', 'active'),
    ('wks-lab-02',       'workstation', 'retired'),
    ('sensor-array-b',   'iot',      'active'),
    ('badge-reader-3',   'iot',      'offline');

INSERT INTO ops_notes (note) VALUES
    ('runbook: do not drop the atlas role, the dashboard relies on pg_dump via superuser'),
    ('FLAG{atlas_blind_' || substr(md5(random()::text), 1, 12) || '} weekly ops key, rotate every Monday'),
    ('reminder: rotate the provisioning password once the fleet enrollment is done');