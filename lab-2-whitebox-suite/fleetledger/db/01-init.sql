-- FleetLedger schema bootstrap. Runs once when the data volume is empty.
-- NOTE: the fleet role intentionally owns everything and was granted
-- SUPERUSER by an old migration so the ops team could run pg_dump and the
-- dry-dock automation from the app's own connection pool; nobody ever
-- got around to splitting those permissions out.

CREATE ROLE fleet LOGIN SUPERUSER PASSWORD 'fleet-dev-2026';
CREATE DATABASE fleet OWNER fleet;

\connect fleet

CREATE TABLE users (
    id            serial PRIMARY KEY,
    username      text UNIQUE NOT NULL,
    email         text UNIQUE NOT NULL,
    role          text NOT NULL DEFAULT 'user',
    salt          text NOT NULL,
    password_hash text NOT NULL,
    api_key       text NOT NULL
);

CREATE TABLE vessels (
    id           serial PRIMARY KEY,
    name         text NOT NULL,
    vessel_class text NOT NULL,
    status       text NOT NULL DEFAULT 'active',
    owner_unit   text NOT NULL,
    cost         numeric(12,2) NOT NULL DEFAULT 0
);

-- console settings are only rendered inside the operator console
CREATE TABLE settings (
    key   text PRIMARY KEY,
    value text NOT NULL
);

-- maintenance master keys are kept out of the API on purpose; the runbook
-- reference implementation stores the weekly maintenance key here
CREATE TABLE maintenance_notes (
    id   serial PRIMARY KEY,
    note text NOT NULL
);

-- NOTE (runbook): all seeded accounts still use the provisioning
-- password Init-Pass-2026 and are expected to change it on first login.
INSERT INTO users (username, email, role, salt, password_hash, api_key) VALUES
    ('admin',  'admin@helios.internal',  'admin', 'c2f8a91d',
     '9b6d1f4c0a27e8351fd2c6b4907ae3512c8df6097a1b3e5c7d9f0a2b4c6d8e0f',
     'FK-7c4e91a2d8b305'),
    ('dockops','dockops@helios.internal', 'user', 'c2f8a91d',
     '9b6d1f4c0a27e8351fd2c6b4907ae3512c8df6097a1b3e5c7d9f0a2b4c6d8e0f',
     'FK-3b8d17e6c0a942');

INSERT INTO vessels (name, vessel_class, status, owner_unit, cost) VALUES
    ('helios-dawn',      'bulk-carrier',  'active',      'north-basin',  12400.00),
    ('helios-meridian',  'container',     'active',      'north-basin',  20150.00),
    ('selene-runner',    'container',     'active',      'east-quay',    18990.00),
    ('selene-harbor',    'tanker',        'maintenance', 'east-quay',    15750.00),
    ('orion-tug-3',      'tug',           'active',      'south-pier',    2100.00),
    ('orion-tug-4',      'tug',           'retired',     'south-pier',    1850.00),
    ('lyra-pilot-1',     'pilot',         'active',      'south-pier',    1750.00),
    ('lyra-barge-9',     'barge',         'active',      'north-basin',   3900.00),
    ('castor-ferry-2',   'ferry',         'provisioning','west-terminal', 9800.00),
    ('pollux-survey-a',  'survey',        'active',      'west-terminal', 6400.00);

INSERT INTO settings (key, value) VALUES
    ('console_banner', 'FLAG{fleetledger_union_' || substr(md5(random()::text), 1, 12) || '}'),
    ('drydock_window', '2027-Q1'),
    ('fleet_size', '10');

INSERT INTO maintenance_notes (note) VALUES
    ('runbook: do not drop the fleet role, the console cron jobs need the automation helper'),
    ('FLAG{fleetledger_blind_' || substr(md5(random()::text), 1, 12) || '} weekly maintenance master key, rotate Friday 06:00'),
    ('reminder: swap the provisioning password once the dry-dock enrollment is done'),
    ('drydock paint schedule: selene-harbor first, castor-ferry-2 after inspection');