# 08 — Repoint DNS for the app-proxied agents

Type: task
Status: resolved
Blocked by: 07

## Question

Repoint DNS for the two `app:`-block hostnames (`aruvii-developer`'s and
`aruvii-qa`'s `app.host`, currently pointed at this VM's IP) to the new
VM's IP. Confirm propagation, and that Caddy on the new VM completes
Let's Encrypt issuance once DNS resolves there.

## Answer

Operator repointed both A records (`dev.aruvii.ai`, `qa.aruvii.ai`) to `13.140.190.206` in the DNS
provider directly. Verified propagation across 3 independent public resolvers (Google 8.8.8.8,
Cloudflare 1.1.1.1, Quad9 9.9.9.9) — all agree.

Caddy's own scheduled retry had backed off for hours (its ACME attempts before the DNS change
correctly failed against the *old* IP, `169.58.40.166`, and it wasn't due to retry again soon) — a
`systemctl restart caddy` forced an immediate fresh attempt, which succeeded within seconds. Real
Let's Encrypt certs issued for both hostnames (issuer "Let's Encrypt E-something", valid
2026-09-27 → 2026-12-26). Verified via `openssl s_client` and a live HTTPS request to each: both
return the expected offline-page fallback (502 by design — no app stack is deployed on the new VM
yet, so `handle_errors` correctly serves `/var/lib/fleet-proxy/offline.html` per ticket 07's setup).
