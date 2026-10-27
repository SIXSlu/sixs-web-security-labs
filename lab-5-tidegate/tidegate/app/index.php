<?php
// TideGate — harbour EDI / customs manifest gateway (public face).
require __DIR__ . '/view.php';

$body = <<<'HTML'
<h1>TideGate</h1>
<div class="card">
<p>TideGate is the harbour's electronic manifest gateway. Freight
partners submit consignment manifests as XML; the customs desk tracks
their clearance here.</p>
</div>

<h2>Track a consignment</h2>
<div class="card" style="max-width:30rem">
<p>Enter a manifest reference to see its clearance status.</p>
<form method="get" action="/track.php">
  <label>Manifest reference <input name="ref" placeholder="TG-1001"></label>
  <button>Track</button>
</form>
</div>

<h2>Partner submission</h2>
<div class="card">
<p>Registered freight partners submit manifests to
<code>POST /gateway/ingest.php</code> with their partner API token in the
<code>X-Partner-Token</code> header. The body is a manifest XML document;
the gateway returns a clearance receipt. See the deployment source for the
accepted schema and the optional field-mapping sheet.</p>
</div>
HTML;

echo tg_page('TideGate', 'harbour gateway', $body);
