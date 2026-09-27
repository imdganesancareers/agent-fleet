# 07 — Stand up Caddy on the new VM

Type: task
Status: resolved
Blocked by: 06

## Question

Run `sudo ./scripts/setup-proxy.sh aruvii` on the new VM to render vhosts
for `aruvii-developer` and `aruvii-qa` (the two agents with an `app:`
block). Unlike `create-agent.sh`, this isn't auto-invoked, so it needs a
deliberate run here. TLS (Let's Encrypt) won't complete until DNS points at
this VM — that's the next ticket — but the vhost config and offline page
can go live first.

## Answer

Ran `sudo /root/projects/agent-fleet/scripts/setup-proxy.sh aruvii` on the new VM (had to use an
absolute path over SSH — relative paths don't resolve against `/root` as the default remote cwd).
Caddy installed, active, and both vhosts rendered correctly:

- `dev.aruvii.ai` → `127.0.0.1:20200` (aruvii-developer)
- `qa.aruvii.ai` → `127.0.0.1:20100` (aruvii-qa)

Both carry the offline-page fallback (`handle_errors` → `/var/lib/fleet-proxy/offline.html`). Verified
`systemctl is-active caddy` → active, and an HTTP request to each vhost correctly 308-redirects to
HTTPS (expected Caddy behavior for a real domain — TLS cert issuance and the offline page's actual
end-to-end serving can't be fully verified until DNS points here, per ticket 08).
