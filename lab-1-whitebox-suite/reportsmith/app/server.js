"use strict";

/**
 * ReportSmith - template-driven reporting service.
 *
 * Users log in, pick a report, and the service renders it with the user's
 * theme preset. Theme presets are plain JSON and are merged over the
 * rendering defaults.
 */
const express = require("express");
const path = require("path");
const crypto = require("crypto");
const fs = require("fs");

const { deepMerge } = require("./lib/merge");
const ejs = require("ejs");

const APP_ROOT = "/opt/reportsmith";
const VIEWS_DIR = path.join(__dirname, "views");

// deployment key for the internal diagnostics endpoint
let DIAG_KEY = "unconfigured";
try {
  DIAG_KEY = fs.readFileSync(path.join(APP_ROOT, "diag.key"), "utf8").trim();
} catch (e) {
  /* diag key not provisioned */
}

// rendering options that every report honors; user presets extend these
const RENDER_DEFAULTS = { cache: false, debug: false };

// feature toggles; "internal" is enabled per-deployment via presets
const FEATURE_DEFAULTS = { reports: true, exports: false, internal: false };

const users = new Map();   // username -> { salt, hash, settings }
const sessions = new Map(); // token -> username

const REPORTS = {
  fleet: {
    title: "Quarterly Fleet Report",
    columns: ["Asset", "Category", "Status"],
    rows: [
      ["edge-router-01", "network", "active"],
      ["srv-erp-01", "server", "active"],
      ["wks-lab-02", "workstation", "retired"]
    ]
  },
  incidents: {
    title: "Incident Summary",
    columns: ["ID", "Severity", "Summary"],
    rows: [
      ["INC-1041", "medium", "badge-reader-3 offline after power work"],
      ["INC-1042", "low", "switch-core-01 maintenance window extended"]
    ]
  }
};

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function currentUser(req) {
  const header = req.headers.authorization || "";
  if (!header.startsWith("Bearer ")) return null;
  const username = sessions.get(header.slice(7));
  return username || null;
}

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.post("/api/register", (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: "username and password required" });
  }
  if (users.has(username)) {
    return res.status(409).json({ error: "username taken" });
  }
  const salt = crypto.randomBytes(4).toString("hex");
  users.set(username, {
    salt: salt,
    hash: sha256(salt + password),
    settings: {}
  });
  res.json({ status: "registered" });
});

app.post("/api/login", (req, res) => {
  const { username, password } = req.body || {};
  const user = users.get(username);
  if (!user || user.hash !== sha256(user.salt + password)) {
    return res.status(401).json({ error: "invalid credentials" });
  }
  const token = crypto.randomBytes(24).toString("hex");
  sessions.set(token, username);
  res.json({ token: token });
});

app.get("/api/me", (req, res) => {
  const username = currentUser(req);
  if (!username) return res.status(401).json({ error: "not authenticated" });
  res.json({ username: username, settings: users.get(username).settings });
});

/**
 * Store a theme preset for the calling user. Presets are merged into the
 * user's stored settings so partial updates are possible.
 */
app.post("/api/profile/theme", (req, res) => {
  const username = currentUser(req);
  if (!username) return res.status(401).json({ error: "not authenticated" });
  const user = users.get(username);
  user.settings = deepMerge(user.settings, req.body || {});
  res.json({ status: "saved", settings: user.settings });
});

/**
 * Internal diagnostics. Only reachable when the deployment enables the
 * internal feature preset.
 */
app.get("/api/internal/diagnostics", (req, res) => {
  const username = currentUser(req);
  if (!username) return res.status(401).json({ error: "not authenticated" });

  const flags = deepMerge({}, FEATURE_DEFAULTS, users.get(username).settings);
  if (flags.internal !== true) {
    return res.status(403).json({ error: "internal diagnostics disabled" });
  }
  res.json({
    internal: true,
    uptime: process.uptime(),
    node: process.version,
    admin_api_key: DIAG_KEY
  });
});

/** Render a report with the caller's theme preset applied. */
app.get("/report/:name", (req, res) => {
  const username = currentUser(req);
  if (!username) return res.status(401).json({ error: "not authenticated" });

  if (!/^[a-z]+$/.test(req.params.name)) {
    return res.status(400).json({ error: "invalid report name" });
  }
  const report = REPORTS[req.params.name];
  if (!report) return res.status(404).json({ error: "unknown report" });

  const user = users.get(username);
  const opts = deepMerge({}, RENDER_DEFAULTS, user.settings);

  ejs.renderFile(
    path.join(VIEWS_DIR, req.params.name + ".ejs"),
    { user: username, report: report },
    opts,
    (err, html) => {
      if (err) {
        console.error("render failed:", err.message);
        return res.status(500).send("render failed");
      }
      res.type("html").send(html);
    }
  );
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`ReportSmith listening on ${PORT}`));