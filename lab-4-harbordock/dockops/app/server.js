const express = require('express');
const ejs = require('ejs');
const crypto = require('crypto');
const { Client } = require('pg');

const app = express();
app.use(express.json({ limit: '256kb' }));

// The ops token is minted into the vault by the provision service and
// the console simply reads whatever is there at boot. The DB is the
// source of truth; nobody copies tokens into config files.
let opsToken = null;

async function readToken() {
  // A new client per attempt: a pg client that has seen a connection
  // error refuses to connect again, which would quietly exhaust the
  // whole retry budget.
  for (let attempt = 0; attempt < 60; attempt++) {
    const client = new Client({
      host: 'harbordock-db',
      user: 'postgres',
      password: 'postgres',
      database: 'harbordock'
    });
    try {
      await client.connect();
      const res = await client.query(
        "SELECT value FROM token_vault WHERE label = 'api_ops'");
      await client.end();
      if (res.rows.length > 0) {
        opsToken = res.rows[0].value;
        console.log('dockops: ops token loaded from vault');
        return;
      }
      console.log('dockops: vault reachable but token not minted yet');
    } catch (err) {
      console.log('dockops: waiting for the vault ...', err.message);
      try { await client.end(); } catch (e) { /* ignore */ }
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  console.log('dockops: giving up on the vault; console stays locked');
}

// Runtime configuration shown on the dashboard. The security review
// wanted deep-merging so operators can patch one nested key without
// rewriting the block - hand rolled, like most review answers.
let runtimeConfig = {
  region: 'quay-west',
  refreshSeconds: 30,
  contacts: {
    dispatcher: 'crane-ops@harbordock.internal',
    emergency: 'harbourmaster@harbordock.internal'
  }
};

function mergeDeep(target, patch) {
  for (const key of Object.keys(patch)) {
    const value = patch[key];
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      target[key] = target[key] || {};
      mergeDeep(target[key], value);
    } else {
      target[key] = value;
    }
  }
  return target;
}

const sessions = new Set();

function requireSession(req, res, next) {
  const header = req.get('Authorization') || '';
  const session = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!session || !sessions.has(session)) {
    return res.status(401).json({ error: 'operator session required' });
  }
  next();
}

const DASHBOARD = `
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>DockOps console</title>
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
<nav class="sx-nav"><a class="sx-brand" href="#"><span class="mark">SX</span> SIXS&nbsp;Labs</a><a class="sx-app" href="/">DockOps</a><span class="sx-tag">operator console</span></nav>
<main>
<h1>DockOps operator console</h1>
<div class="card">
<p>Shift token accepted. Runtime configuration:</p>
<pre><%= runtimeJson %></pre>
</div>
<h2>Cranes diagnostics</h2>
<pre class="card"><%= typeof diagnostics !== 'undefined' ? diagnostics : 'no diagnostics for this shift yet' %></pre>
</main>
<footer class="sx-foot"><span class="mark">SX</span> A SIXS security training lab <span>·</span> no packets were harmed in the making of this lab (a few got definetly roughed up)</footer>
</body></html>
`;

app.get('/health', (req, res) => res.json({ up: true, console: 'dockops' }));

app.post('/api/session', (req, res) => {
  const token = (req.body || {}).token;
  if (!token || token !== opsToken) {
    return res.status(403).json({ error: 'unknown operator token' });
  }
  const sid = crypto.randomBytes(16).toString('hex');
  sessions.add(sid);
  res.json({ session: sid });
});

app.put('/api/runtime', requireSession, (req, res) => {
  const settings = (req.body || {}).settings;
  if (!settings || typeof settings !== 'object') {
    return res.status(400).json({ error: 'settings object required' });
  }
  mergeDeep(runtimeConfig, settings);
  res.json({ ok: true, settings: runtimeConfig });
});

app.get('/dashboard', requireSession, (req, res) => {
  const html = ejs.render(DASHBOARD, { runtimeJson: JSON.stringify(runtimeConfig, null, 2) });
  res.send(html);
});

readToken().then(() => {
  app.listen(3000, () => console.log('dockops: listening on 3000'));
});