# 08 — Repoint DNS for the app-proxied agents

Type: task
Status: open
Blocked by: 07

## Question

Repoint DNS for the two `app:`-block hostnames (`aruvii-developer`'s and
`aruvii-qa`'s `app.host`, currently pointed at this VM's IP) to the new
VM's IP. Confirm propagation, and that Caddy on the new VM completes
Let's Encrypt issuance once DNS resolves there.
