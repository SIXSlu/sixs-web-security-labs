-- ------------------------------------------------------------------
-- HarborDock bootstrap. Runs on every container start: the database
-- data directory is a tmpfs, so nothing here survives a restart.
-- The flag/token values are minted here, exactly once per start.
-- ------------------------------------------------------------------

CREATE TABLE manifests (
    id     serial PRIMARY KEY,
    vessel text NOT NULL,
    port   text NOT NULL,
    cargo  text NOT NULL,
    status text NOT NULL
);

CREATE TABLE system_notes (
    id   serial PRIMARY KEY,
    note text NOT NULL
);

CREATE TABLE token_vault (
    label text PRIMARY KEY,
    value text NOT NULL
);

INSERT INTO manifests (vessel, port, cargo, status) VALUES
    ('MV Aegir Dawn',  'ROTTERDAM', 'flat-rolled steel',  'berthed'),
    ('MV Kaiyō Maru',  'HAMBURG',   'ro-ro trailers',     'assisting'),
    ('MV Selkie Light','ANTWERP',   'project cargo',      'berthed'),
    ('MV Tindra Sky',  'ROTTERDAM', 'soybean meal',       'assisting'),
    ('MV Bruma Norte', 'BREMEN',    'wind turbine blades','anchored'),
    ('MV Odysseus',    'HAMBURG',   'palletised timber',  'berthed'),
    ('MV Corvo Star',  'ANTWERP',   'bananas (reefer)',   'anchored'),
    ('MV Mistral Bore','ROTTERDAM', 'diesel EN590',       'assisting'),
    ('MV Thalassa II', 'BREMEN',    'cement clinker',     'berthed'),
    ('MV Polar Lyre',  'ROTTERDAM', 'LNG (exempt list)',  'anchored');

INSERT INTO system_notes (note) VALUES
    ('Weekly rota: night watch covers cranes 4-7 until the refit.'),
    ('Reefer alarm thresholds raised 0.5C after the vendor visit.'),
    (format('FLAG{%s}', md5(random()::text))),
    ('Car park level 2 reopens after the coating works.');

INSERT INTO token_vault (label, value) VALUES
    ('api_ops', md5(random()::text || clock_timestamp()::text)),
    ('seal',    format('FLAG{%s}', md5(random()::text)));

-- Split console: the search API and the stats API use different DB
-- logins and the vault is deliberately not granted to the search one.
CREATE ROLE appsearch LOGIN PASSWORD 'appsearch';
CREATE ROLE appstats  LOGIN PASSWORD 'appstats';
GRANT SELECT ON manifests, system_notes TO appsearch;
GRANT SELECT ON manifests, token_vault TO appstats;