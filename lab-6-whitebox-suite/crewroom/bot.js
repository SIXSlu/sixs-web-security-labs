'use strict';
// The duty stationmaster bot.
//
// The stationmaster keeps a signed-in browser session on the crew wall
// so defacement gets seen quickly: every few seconds the bot taps in
// fresh (the admin tap is only valid for 60 seconds) and loads the wall
// exactly like a real supervisor browser would - scripts on, resources
// on, and the session token sitting in localStorage where the console
// script expects it.

const { JSDOM } = require('jsdom');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3000';
const PASSWORD = process.env.SUPERVISOR_PASSWORD;
const INTERVAL = parseInt(process.env.BOT_INTERVAL || '20', 10) * 1000;
const DWELL = 5000; // how long the supervisor keeps the wall open

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function tap() {
    const r = await fetch(`${BASE}/api/auth/tap`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ username: 'stationmaster', password: PASSWORD }),
    });
    if (!r.ok) throw new Error(`tap failed: ${r.status}`);
    const session = await r.json();
    if (session.role !== 'admin') throw new Error('tap did not yield the admin role');
    return session.token;
}

async function round() {
    const token = await tap();
    const r = await fetch(`${BASE}/`);
    if (!r.ok) throw new Error(`wall failed: ${r.status}`);
    const dom = new JSDOM(await r.text(), {
        url: `${BASE}/`,
        runScripts: 'dangerously',
        resources: 'usable',
        pretendToBeVisual: true,
        beforeParse(window) {
            window.localStorage.setItem('crewroom_token', token);
            window.localStorage.setItem('crewroom_user', 'stationmaster');
        },
    });
    setTimeout(() => { try { dom.window.close(); } catch { /* already gone */ } }, DWELL);
}

(async () => {
    if (!PASSWORD) {
        console.error('[bot] no SUPERVISOR_PASSWORD in the environment');
        process.exit(1);
    }
    // wait for the wall to come up, then keep the supervisor session warm
    for (;;) {
        try {
            await round();
            console.log('[bot] stationmaster is watching the wall');
            break;
        } catch (e) {
            await sleep(3000);
        }
    }
    setInterval(() => {
        round().catch((e) => console.error('[bot] round failed:', e.message));
    }, INTERVAL);
})();