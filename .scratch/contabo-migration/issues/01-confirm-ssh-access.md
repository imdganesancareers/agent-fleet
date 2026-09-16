# 01 — Confirm root SSH access to the new Contabo VM

Type: task
Status: open

## Question

Confirm (or establish) root SSH access from this VM to the new Contabo VM:
public key in place, port/firewall reachable, IP address recorded. Everything
downstream — the repo clone, the fleet-secrets rsync, and every lifecycle
script run on the new box — happens over this connection, so this is the
one thing that blocks the whole rest of the map.
