// CrewRoom - the Copperline Railway crew notice wall.
//
// Node 20 + Express. The wall itself is a static page; everything else
// is a JSON REST API:
//
//   POST /api/notices        pin a note to the wall (public)
//   GET  /api/notices        read the wall (public)
//   POST /api/auth/tap       crew session tap (staff / stationmaster)
//   GET  /api/admin/briefing stationmaster briefing (admin tap)
//   POST /api/admin/settings wall settings (admin tap)
//   POST /api/admin/backup  archive the wall for the depot handover (admin)
//
// Sessions are bearer tokens minted by /api/auth/tap. Staff taps last
// an hour; the stationmaster's tap is deliberately short-lived (60s)
// because the console script refreshes it constantly.
//
// (No "use strict" in here: the merge helper below predates the strict
// pragma - it was inherited from the booking-hall display board and
// has never been modernised.)

const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const PORT = process.env.PORT || 3000;
const BACKUP = '/usr/local/bin/crewroom-backup';

// ---------------------------------------------------------------------
// crew accounts
// ---------------------------------------------------------------------
// Staff accounts are shared (the combination is on the crew-room door,
// it only lets you pin notes). The stationmaster's password is
// provisioned at deploy time by the entrypoint and never lives in the
// image or the repo.
const SUPERVISOR = 'stationmaster';
const SUPERVISOR_PASSWORD = process.env.SUPERVISOR_PASSWORD || '';
const STAFF_PASSWORD = 'copperline-crew';
const TTL = { admin: 60, staff: 3600 };

const tokens = new Map();

// ---------------------------------------------------------------------
// wall settings (mutable from the admin console)
// ---------------------------------------------------------------------
const settings = {
    station: 'Copperline Central',
    retention_days: 30,
};

// The admin console saves settings as a JSON document; the merge walks
// the incoming document and overlays it onto the current settings. It
// has done so since the first release and nobody has ever had a reason
// to look closely at it.
function deepMerge(dst, src) {
    for (const key in src) {
        if (src[key] !== null && typeof src[key] === 'object') {
            dst[key] = dst[key] || {};
            deepMerge(dst[key], src[key]);
        } else {
            dst[key] = src[key];
        }
    }
    return dst;
}

const app = express();
app.use(express.json({ limit: '64kb' }));

// The railway security office pinned the crew room browser policy down:
// nothing the wall loads may talk to anything but the wall itself, so a
// compromised kiosk cannot ship data off the station network.
app.use((req, res, next) => {
    res.set('Content-Security-Policy',
        "default-src 'self'; img-src * data:; " +
        "script-src 'self' 'unsafe-inline'; style-src 'self'; " +
        "connect-src 'self'");
    next();
});

// ---------------------------------------------------------------------
// notices
// ---------------------------------------------------------------------
let notices = [];
let nextId = 1;

app.get('/api/notices', (req, res) => {
    res.json({ notices });
});

app.post('/api/notices', (req, res) => {
    const author = String((req.body || {}).author || 'anonymous').slice(0, 40);
    const body = String((req.body || {}).body || '').slice(0, 2000);
    const notice = { id: nextId++, author, body, at: new Date().toISOString() };
    notices.push(notice);
    res.status(201).json(notice);
});

// ---------------------------------------------------------------------
// sessions
// ---------------------------------------------------------------------
function mint(role, username) {
    const token = crypto.randomBytes(24).toString('hex');
    const ttl = TTL[role];
    tokens.set(token, { role, username, expires: Date.now() + ttl * 1000 });
    // opportunistic sweep of expired taps
    for (const [k, v] of tokens) {
        if (v.expires <= Date.now()) tokens.delete(k);
    }
    return { token, role, username, expires_in: ttl };
}

app.post('/api/auth/tap', (req, res) => {
    const username = String((req.body || {}).username || '');
    const password = String((req.body || {}).password || '');
    if (SUPERVISOR_PASSWORD && username === SUPERVISOR
        && password === SUPERVISOR_PASSWORD) {
        return res.json(mint('admin', SUPERVISOR));
    }
    if (username === 'crew' && password === STAFF_PASSWORD) {
        return res.json(mint('staff', username));
    }
    res.status(403).json({ error: 'unknown crew member' });
});

function requireRole(role) {
    return (req, res, next) => {
        const m = (req.get('authorization') || '').match(/^Bearer (\S+)$/);
        const tap = m && tokens.get(m[1]);
        if (!tap || tap.expires <= Date.now()) {
            return res.status(401).json({ error: 'a valid crew tap is required' });
        }
        if (tap.role !== role) {
            return res.status(403).json({ error: `the ${role} role is required` });
        }
        req.crew = tap;
        next();
    };
}

// ---------------------------------------------------------------------
// stationmaster console
// ---------------------------------------------------------------------
app.get('/api/admin/briefing', requireRole('admin'), (req, res) => {
    res.json({
        briefing: fs.readFileSync('/opt/crewroom/briefing.txt', 'utf8').trim(),
    });
});

app.post('/api/admin/settings', requireRole('admin'), (req, res) => {
    deepMerge(settings, req.body || {});
    res.json({ ok: true, settings });
});

app.post('/api/admin/backup', requireRole('admin'), (req, res) => {
    // The depot handover wants the wall archived under a tag the
    // stationmaster chooses. Depots run the archiver in shell mode when
    // they want date patterns substituted into the tag, so the mode is
    // a wall setting like any other.
    const archive = String((req.body || {}).archive || 'crewroom');
    const opts = { encoding: 'utf8' };
    if (settings.backup_shell_mode) {
        opts.shell = true;
    }
    const result = spawnSync(BACKUP, [archive], opts);
    res.json({
        ok: result.status === 0,
        output: result.stdout,
        stderr: result.stderr,
    });
});

// ---------------------------------------------------------------------
// static wall
// ---------------------------------------------------------------------
app.use(express.static(path.join(__dirname, 'public')));
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`crewroom wall listening on ${PORT}`);
});