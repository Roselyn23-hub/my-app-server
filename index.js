const express = require('express');
const { createClient } = require('@supabase/supabase-js');

const app = express();

// Same Supabase project your Flutter app uses (anon/public key — safe to
// use here since it's already embedded in the app itself).
const supabase = createClient(
  'https://sjipwvbiwbbnqnwjqaoy.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqaXB3dmJpd2JibnFud2pxYW95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2Nzg5NzQsImV4cCI6MjEwMjI1NDk3NH0.EqvXOy39PCZQEKkpbmsTwwXFuY5azpyQfmI-zhXmnxc'
);

const STATUS_COLORS = {
  Pending: '#e67e22',
  'In-Transit': '#2980b9',
  Received: '#16a085',
  Approved: '#27ae60',
  Completed: '#27ae60',
  Rejected: '#c0392b',
};

function escapeHtml(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatDate(iso) {
  if (!iso) return '';
  try {
    const d = new Date(iso);
    return d.toLocaleString('en-US', {
      month: 'short', day: 'numeric', year: 'numeric',
      hour: 'numeric', minute: '2-digit',
    });
  } catch {
    return iso;
  }
}

app.get('/doc/:id', async (req, res) => {
  const qrCode = req.params.id;

  const { data: doc, error: docError } = await supabase
    .from('documents')
    .select()
    .eq('qr_code', qrCode)
    .maybeSingle();

  if (docError) {
    return res.status(500).send('Something went wrong loading this document.');
  }

  if (!doc) {
    return res.status(404).send(renderNotFoundPage());
  }

  const { data: route } = await supabase
    .from('document_routes')
    .select()
    .eq('qr_code', qrCode)
    .order('step_order', { ascending: true });

  const { data: logs } = await supabase
    .from('tracking_logs')
    .select()
    .eq('qr_code', qrCode)
    .order('timestamp', { ascending: false });

  res.send(renderDocPage(doc, route || [], logs || []));
});

function renderNotFoundPage() {
  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Document not found</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; background:#f5f0e6; color:#3a2a1a;
         display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
  .box { text-align:center; padding:24px; }
</style></head>
<body><div class="box"><h2>Document not found</h2><p>This QR code doesn't match any document on file.</p></div></body>
</html>`;
}

function renderDocPage(doc, route, logs) {
  const color = STATUS_COLORS[doc.status] || '#7f8c8d';

  const routeHtml = route.length
    ? `<div class="card">
        <h3>Signing Route</h3>
        <ol class="route-list">
          ${route.map(r => `
            <li class="${r.status === 'Completed' ? 'done' : ''}">
              <span class="dot"></span>
              <div>
                <div class="route-name">${escapeHtml(r.assigned_to)}</div>
                <div class="route-status">${escapeHtml(r.status)}${r.completed_at ? ' • ' + formatDate(r.completed_at) : ''}</div>
              </div>
            </li>`).join('')}
        </ol>
      </div>`
    : '';

  const logsHtml = logs.length
    ? logs.map(l => `
        <div class="log-item">
          <div class="log-title">${escapeHtml(l.action)} by ${escapeHtml(l.performed_by)}${l.forwarded_to ? ' → ' + escapeHtml(l.forwarded_to) : ''}</div>
          <div class="log-date">${formatDate(l.timestamp)}</div>
        </div>`).join('')
    : '<p class="muted">No activity yet.</p>';

  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(doc.title)}</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; background:#f5f0e6; color:#3a2a1a;
         margin:0; padding:20px; }
  .container { max-width: 560px; margin: 0 auto; }
  .card { background:#fff; border-radius:14px; padding:18px; margin-bottom:16px;
          border:1px solid rgba(180,140,60,0.25); box-shadow:0 2px 6px rgba(0,0,0,0.04); }
  h1 { font-size:20px; margin:0 0 8px; color:#5a1a1a; }
  h3 { font-size:15px; margin:0 0 10px; color:#5a1a1a; }
  .badge { display:inline-block; padding:4px 10px; border-radius:8px; font-size:12px; font-weight:bold;
           color:${color}; background:${color}22; }
  .row { display:flex; padding:4px 0; font-size:14px; }
  .row .label { width:130px; color:#888; flex-shrink:0; }
  .row .value { font-weight:500; }
  .route-list { list-style:none; padding:0; margin:0; }
  .route-list li { display:flex; align-items:center; gap:10px; padding:6px 0; opacity:0.55; }
  .route-list li.done { opacity:1; }
  .dot { width:10px; height:10px; border-radius:50%; background:#ccc; flex-shrink:0; }
  .route-list li.done .dot { background:#27ae60; }
  .route-name { font-weight:600; font-size:14px; }
  .route-status { font-size:12px; color:#888; }
  .log-item { padding:8px 0; border-bottom:1px solid #eee2cc; }
  .log-item:last-child { border-bottom:none; }
  .log-title { font-size:14px; font-weight:600; }
  .log-date { font-size:12px; color:#888; }
  .muted { color:#888; font-size:14px; }
</style></head>
<body>
  <div class="container">
    <div class="card">
      <h1>${escapeHtml(doc.title)}</h1>
      <span class="badge">${escapeHtml(doc.status)}</span>
      <div style="height:14px"></div>
      <div class="row"><div class="label">Type</div><div class="value">${escapeHtml(doc.document_type)}</div></div>
      ${doc.description ? `<div class="row"><div class="label">Description</div><div class="value">${escapeHtml(doc.description)}</div></div>` : ''}
      <div class="row"><div class="label">Current holder</div><div class="value">${escapeHtml(doc.current_holder)}</div></div>
      <div class="row"><div class="label">Created by</div><div class="value">${escapeHtml(doc.created_by)}</div></div>
    </div>
    ${routeHtml}
    <div class="card">
      <h3>Tracking History</h3>
      ${logsHtml}
    </div>
  </div>
</body>
</html>`;
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));