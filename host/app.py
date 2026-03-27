from flask import Flask, request, Response
import os

app = Flask(__name__)

HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>NetDiag — Network Diagnostic Suite</title>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet"/>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --bg:        #F5F6FA;
      --surface:   #FFFFFF;
      --border:    #E2E5ED;
      --accent:    #1B54E8;
      --accent-lt: #EEF2FF;
      --text:      #0F172A;
      --muted:     #64748B;
      --success:   #16A34A;
      --danger:    #DC2626;
      --mono:      'DM Mono', monospace;
    }

    body {
      font-family: 'DM Sans', sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    /* ── Top bar ── */
    header {
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      padding: 0 2.5rem;
      height: 56px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      position: sticky;
      top: 0;
      z-index: 10;
    }

    .logo {
      display: flex;
      align-items: center;
      gap: 10px;
      font-weight: 600;
      font-size: 1rem;
      letter-spacing: -.01em;
    }

    .logo-icon {
      width: 30px; height: 30px;
      background: var(--accent);
      border-radius: 7px;
      display: grid;
      place-items: center;
    }

    .logo-icon svg { width: 16px; height: 16px; }

    nav {
      display: flex;
      gap: 0.25rem;
    }

    nav a {
      text-decoration: none;
      font-size: .875rem;
      font-weight: 500;
      color: var(--muted);
      padding: 6px 14px;
      border-radius: 6px;
      transition: background .15s, color .15s;
    }

    nav a.active, nav a:hover {
      background: var(--accent-lt);
      color: var(--accent);
    }

    .badge {
      font-size: .7rem;
      font-weight: 600;
      background: #FEF3C7;
      color: #92400E;
      border: 1px solid #FDE68A;
      padding: 2px 8px;
      border-radius: 99px;
      letter-spacing: .03em;
    }

    /* ── Layout ── */
    main {
      flex: 1;
      max-width: 860px;
      width: 100%;
      margin: 0 auto;
      padding: 2.5rem 1.5rem;
    }

    .page-title {
      font-size: 1.5rem;
      font-weight: 600;
      letter-spacing: -.02em;
      margin-bottom: .35rem;
    }

    .page-sub {
      color: var(--muted);
      font-size: .9rem;
      margin-bottom: 2rem;
    }

    /* ── Card ── */
    .card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      overflow: hidden;
      margin-bottom: 1.5rem;
    }

    .card-header {
      padding: 1rem 1.5rem;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .card-header-icon {
      width: 28px; height: 28px;
      background: var(--accent-lt);
      border-radius: 6px;
      display: grid;
      place-items: center;
      flex-shrink: 0;
    }

    .card-header-icon svg { width: 14px; height: 14px; color: var(--accent); }

    .card-title {
      font-size: .95rem;
      font-weight: 600;
    }

    .card-body { padding: 1.5rem; }

    /* ── Form ── */
    label {
      display: block;
      font-size: .8rem;
      font-weight: 600;
      letter-spacing: .04em;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: .5rem;
    }

    .input-row {
      display: flex;
      gap: .75rem;
      align-items: flex-start;
    }

    textarea {
      flex: 1;
      font-family: var(--mono);
      font-size: 1rem;
      padding: .85rem 1rem;
      border: 1.5px solid var(--border);
      border-radius: 8px;
      background: var(--bg);
      color: var(--text);
      resize: vertical;
      min-height: 80px;
      line-height: 1.6;
      transition: border-color .15s, box-shadow .15s;
      outline: none;
    }

    textarea:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(27,84,232,.1);
      background: #fff;
    }

    textarea::placeholder { color: #94A3B8; }

    button[type=submit] {
      padding: .85rem 1.6rem;
      background: var(--accent);
      color: #fff;
      font-family: 'DM Sans', sans-serif;
      font-size: .9rem;
      font-weight: 600;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      white-space: nowrap;
      transition: background .15s, transform .1s;
      align-self: flex-end;
    }

    button[type=submit]:hover { background: #1344cc; }
    button[type=submit]:active { transform: scale(.97); }

    .hint {
      margin-top: .6rem;
      font-size: .78rem;
      color: var(--muted);
    }

    /* ── Output ── */
    .output-block {
      background: #0F172A;
      border-radius: 10px;
      overflow: hidden;
    }

    .output-bar {
      padding: .6rem 1rem;
      background: #1E293B;
      display: flex;
      align-items: center;
      gap: .5rem;
    }

    .dot { width: 10px; height: 10px; border-radius: 50%; }
    .dot-r { background: #EF4444; }
    .dot-y { background: #F59E0B; }
    .dot-g { background: #22C55E; }

    .output-label {
      font-family: var(--mono);
      font-size: .72rem;
      color: #64748B;
      margin-left: auto;
    }

    pre {
      font-family: var(--mono);
      font-size: .85rem;
      color: #94A3B8;
      padding: 1.25rem 1.5rem;
      white-space: pre-wrap;
      word-break: break-all;
      line-height: 1.7;
      max-height: 340px;
      overflow-y: auto;
    }

    pre .ok   { color: #4ADE80; }
    pre .warn { color: #FCD34D; }
    pre .err  { color: #F87171; }

    /* ── Info pills ── */
    .info-row {
      display: flex;
      gap: .75rem;
      flex-wrap: wrap;
      margin-top: 1.5rem;
    }

    .info-pill {
      display: flex;
      align-items: center;
      gap: .4rem;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: .6rem .9rem;
      font-size: .82rem;
    }

    .pill-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--success); }
    .pill-label { color: var(--muted); }
    .pill-val { font-weight: 600; }

    /* ── Footer ── */
    footer {
      text-align: center;
      padding: 1.5rem;
      font-size: .78rem;
      color: #94A3B8;
      border-top: 1px solid var(--border);
    }
  </style>
</head>
<body>

<header>
  <div class="logo">
    <div class="logo-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/>
        <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
      </svg>
    </div>
    NetDiag
  </div>
  <nav>
    <a href="#" class="active">Ping</a>
    <a href="#">Traceroute</a>
    <a href="#">DNS Lookup</a>
    <a href="#">Port Scan</a>
  </nav>
  <span class="badge">INTERNAL USE ONLY</span>
</header>

<main>
  <div class="page-title">Network Diagnostic Suite</div>
  <div class="page-sub">Run live network diagnostics from the server. Results reflect server-side connectivity.</div>

  <div class="card">
    <div class="card-header">
      <div class="card-header-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>
        </svg>
      </div>
      <span class="card-title">Ping Host</span>
    </div>
    <div class="card-body">
      <form method="GET" action="/ping">
        <label for="host">Target Hostname or IP Address</label>
        <div class="input-row">
          <textarea
            id="host"
            name="host"
            placeholder="e.g.  8.8.8.8  or  google.com"
            spellcheck="false"
            autocomplete="off"
          >%(host)s</textarea>
          <button type="submit">Run Ping</button>
        </div>
        <p class="hint">Sends ICMP echo requests from the diagnostic server. Supports hostnames and IPv4/IPv6 addresses.</p>
      </form>
    </div>
  </div>

  %(output)s

  <div class="info-row">
    <div class="info-pill">
      <div class="pill-dot"></div>
      <span class="pill-label">Server</span>
      <span class="pill-val">diag-srv-01</span>
    </div>
    <div class="info-pill">
      <div class="pill-dot"></div>
      <span class="pill-label">Region</span>
      <span class="pill-val">IN-West</span>
    </div>
    <div class="info-pill">
      <div class="pill-dot" style="background:#F59E0B"></div>
      <span class="pill-label">Auth</span>
      <span class="pill-val">Internal Network</span>
    </div>
  </div>
</main>

<footer>NetDiag v2.4.1 &nbsp;·&nbsp; Infrastructure Tools &nbsp;·&nbsp; Restricted to internal network</footer>

</body>
</html>"""

OUTPUT_TMPL = """
<div class="card">
  <div class="card-header">
    <div class="card-header-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/>
      </svg>
    </div>
    <span class="card-title">Output</span>
  </div>
  <div class="card-body">
    <div class="output-block">
      <div class="output-bar">
        <div class="dot dot-r"></div>
        <div class="dot dot-y"></div>
        <div class="dot dot-g"></div>
        <span class="output-label">ping &mdash; {host}</span>
      </div>
      <pre>{result}</pre>
    </div>
  </div>
</div>
"""

@app.route('/')
def index():
    return HTML.replace('%(host)s', '').replace('%(output)s', '')

@app.route('/ping')
def ping():
    host = request.args.get('host', '').strip()
    if not host:
        return HTML % {'host': '', 'output': ''}

    # INTENTIONALLY VULNERABLE — for educational demonstration only
    result = os.popen("ping -c 3 " + host).read()
    if not result:
        result = "(no output)"

    output = OUTPUT_TMPL.format(
        host=host.replace('<', '&lt;').replace('>', '&gt;'),
        result=result.replace('<', '&lt;').replace('>', '&gt;')
    )
    return HTML.replace('%(host)s', host).replace('%(output)s', output)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)

