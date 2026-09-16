# 07 — Stand up Caddy on the new VM

Type: task
Status: open
Blocked by: 06

## Question

Run `sudo ./scripts/setup-proxy.sh aruvii` on the new VM to render vhosts
for `aruvii-developer` and `aruvii-qa` (the two agents with an `app:`
block). Unlike `create-agent.sh`, this isn't auto-invoked, so it needs a
deliberate run here. TLS (Let's Encrypt) won't complete until DNS points at
this VM — that's the next ticket — but the vhost config and offline page
can go live first.
