<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PrintBay — theme preview</title>
<style>
:root{--cream:#f5f1ea;--ink:#2b2620;--gold:#f0c64c;--line:#e4dccb;--card:#fffdf8}
*{box-sizing:border-box}
body{font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;margin:0;background:var(--cream);color:var(--ink);line-height:1.6}
.pbnav{display:flex;align-items:center;gap:1.1rem;flex-wrap:wrap;background:var(--ink);color:var(--cream);padding:14px 28px;box-shadow:0 1px 0 rgba(0,0,0,.25)}
.pbnav strong{font-family:Georgia,"Times New Roman",serif;font-size:1.15rem;letter-spacing:.02em}
.pbnav a{color:var(--gold);text-decoration:none;font-size:.92rem}
.pbnav a:hover{text-decoration:underline}
main{max-width:900px;margin:2.2rem auto;padding:0 1.2rem}
h1{font-family:Georgia,serif;font-size:1.9rem;margin:.2rem 0 1rem}
h2{font-family:Georgia,serif;font-size:1.25rem}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:1.2rem 1.5rem;margin:1.1rem 0;box-shadow:0 2px 10px rgba(43,38,32,.05)}
table{border-collapse:collapse;width:100%}
td,th{padding:.5rem .7rem;border-bottom:1px solid var(--line);text-align:left}
code{background:#efe7d6;padding:2px 7px;border-radius:5px;font-family:ui-monospace,Menlo,monospace}
.error{color:#a33}
.pbfoot{max-width:900px;margin:2.5rem auto 2rem;padding:1.1rem 1.2rem 0;border-top:1px solid var(--line);display:flex;gap:.6rem;align-items:center;flex-wrap:wrap;color:#8a7f6d;font-size:.82rem}
.pbfoot .mark{display:inline-grid;place-items:center;width:18px;height:18px;background:var(--ink);color:var(--cream);font-weight:800;font-size:.55rem;border-radius:3px}
.pbfoot a{color:#6f6552;text-decoration:none}.pbfoot a:hover{color:var(--ink)}
</style>
</head>
<body>
<nav class="pbnav"><strong>PrintBay</strong>
<a href="/index.php">home</a>
<a href="/index.php?page=gallery">gallery</a>
<a href="/index.php?page=preview">preview a theme</a>
</nav>
<main>
<h1>Theme previewer</h1>
<p>Try a shipped theme (e.g. <code>flyer.php</code>, <code>card.php</code>)
or paste a design-team scratch stream. Previewed themes can be posted or
bookmarked.</p>
<form method="post" action="/index.php?page=preview">
<label for="theme">theme</label>
<input type="text" id="theme" name="theme" placeholder="flyer.php">
<button type="submit">preview</button>
</form>
<div class="pane" id="preview-pane">
