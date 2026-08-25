#!/usr/bin/env bash
# setup-proxy.sh — host-level reverse proxy (Caddy) for a fleet's app stacks.
#
# Every agent whose recipe declares an `app:` block —
#   app:
#     host: qa.example.com   # DNS name pointing at this VM
#     port: 20100            # the agent's assigned host port (HTTP entry)
# — gets a vhost: https://<host> → 127.0.0.1:<port>. TLS is automatic
# (Let's Encrypt; DNS must already point here and 80/443 be reachable). When
# the agent's stack is down, the vhost serves a static offline page instead
# of a bare 502.
#
#   sudo ./scripts/setup-proxy.sh <fleet>
#   FLEET=<fleet> sudo ./scripts/setup-proxy.sh
#
# Rerunnable: rerenders /etc/caddy/Caddyfile (fully managed by this script —
# hand edits are overwritten) and reloads Caddy.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok \033[0m%s\n' "$*"; }
warn() { printf '\033[1;33mwarn\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mfail\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
source "$SCRIPT_DIR/fleet-lib.sh"

USAGE="usage: sudo $0 <fleet>   (or FLEET=<fleet> sudo $0)"

fleet_args 0 "$@"
[[ $EUID -eq 0 ]] || die "must run as root"
[[ -d $FLEET_DIR/agents ]] || die "no fleet agents dir at $FLEET_DIR/agents"

# ---------- install caddy ----------
if command -v caddy >/dev/null; then
  ok " caddy present"
else
  log "installing caddy"
  apt-get update -qq
  if ! apt-get install -y -qq caddy 2>/dev/null; then
    # not in the distro repos — use Caddy's official apt repo
    apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl gnupg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
      | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
      > /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq
    apt-get install -y -qq caddy
  fi
  ok " caddy installed"
fi

# ---------- offline fallback page ----------
install -d -m 0755 /var/lib/fleet-proxy
cat > /var/lib/fleet-proxy/offline.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Environment offline</title>
<style>
  body { margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
         background:#0f1218; color:#e6e9ef; font:16px/1.6 system-ui, sans-serif; }
  main { text-align:center; padding:2rem; }
  h1 { font-size:1.6rem; margin:0 0 .5rem; }
  p  { margin:.25rem 0; color:#9aa3b2; }
  .dot { display:inline-block; width:.6rem; height:.6rem; border-radius:50%;
         background:#e0a336; margin-right:.5rem; vertical-align:baseline; }
</style>
</head>
<body>
<main>
  <h1><span class="dot"></span>This environment is offline</h1>
  <p>No build is running behind this address right now.</p>
  <p>If you expected one, ask in the team's Discord channel.</p>
</main>
</body>
</html>
HTML
ok " offline page at /var/lib/fleet-proxy/offline.html"

# ---------- render Caddyfile from the fleet's app blocks ----------
python3 - "$FLEET_DIR/agents" > /etc/caddy/Caddyfile.fleet-new <<'PY' || die "render failed"
import os, sys, yaml

d = sys.argv[1]
vhosts = []
for n in sorted(os.listdir(d)):
    p = os.path.join(d, n, 'agent.yaml')
    if not os.path.isfile(p):
        continue
    app = (yaml.safe_load(open(p)) or {}).get('app') or {}
    host, port = app.get('host'), app.get('port')
    if not (host and port):
        continue
    port = int(port)
    if not 1024 <= port <= 65535:
        sys.exit(f"{n}: app.port {port} out of range")
    vhosts.append((str(host), port, n))

if not vhosts:
    sys.exit("no agent in this fleet declares an app: block (host + port) — nothing to proxy")

print("# Managed by agent-fleet scripts/setup-proxy.sh — do not edit by hand.")
print("{\n\tadmin off\n}")
for host, port, agent in vhosts:
    print(f"""
# {agent}
{host} {{
\treverse_proxy 127.0.0.1:{port}
\thandle_errors {{
\t\troot * /var/lib/fleet-proxy
\t\trewrite * /offline.html
\t\theader Cache-Control no-store
\t\tfile_server
\t}}
}}""")
PY
caddy validate --config /etc/caddy/Caddyfile.fleet-new >/dev/null 2>&1 \
  || { caddy validate --config /etc/caddy/Caddyfile.fleet-new; die "rendered Caddyfile invalid — old config untouched"; }
mv /etc/caddy/Caddyfile.fleet-new /etc/caddy/Caddyfile
ok " Caddyfile rendered ($(grep -c reverse_proxy /etc/caddy/Caddyfile) vhost(s))"

# ---------- run it ----------
systemctl enable --now caddy >/dev/null 2>&1
systemctl reload caddy 2>/dev/null || systemctl restart caddy
systemctl is-active --quiet caddy || die "caddy failed to start — journalctl -u caddy"
ok " caddy active"

echo
log "vhosts:"
grep -B1 'reverse_proxy' /etc/caddy/Caddyfile | grep -v '^--' | sed 's/^/  /'
cat <<'EOF'
  TLS certificates are fetched automatically on first request per hostname
  (DNS must point at this VM; ports 80+443 reachable). While an agent's stack
  is down its URL serves the offline page.
EOF
