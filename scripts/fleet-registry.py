#!/usr/bin/env python3
"""fleet-registry.py — the ONLY code that writes fleet.yaml.

The lifecycle scripts call this; nothing else (human hands included) edits the
registry. Entries hold exactly: name, status, created, purpose, retired.

usage:
  fleet-registry.py <fleet.yaml> upsert <name> --purpose-from <agent.yaml> [--created YYYY-MM-DD]
      activate <name>: keep an existing created date (or stamp today / --created),
      refresh purpose from the agent.yaml's first purpose line, drop any retired date
  fleet-registry.py <fleet.yaml> set-purpose <name> --purpose-from <agent.yaml>
      refresh purpose only; entry must exist
  fleet-registry.py <fleet.yaml> retire <name>
      set status: retired and stamp retired: today; fails if missing or already retired
  fleet-registry.py <fleet.yaml> get <name> <field>
      print one field of one entry (empty + exit 1 if missing)
"""
import datetime
import sys

import yaml

HEADER = (
    "# fleet.yaml — registry of record for the agents on this VM.\n"
    "# Written only by the lifecycle scripts in scripts/ — never edit by hand.\n"
    "# Fields per entry: name, status (active|retired), created, purpose, retired.\n"
)


def load(path):
    try:
        data = yaml.safe_load(open(path)) or {}
    except FileNotFoundError:
        data = {}
    agents = data.get("agents") or []
    if not isinstance(agents, list):
        sys.exit(f"{path}: 'agents' must be a list")
    return agents


def save(path, agents):
    body = yaml.safe_dump(
        {"agents": sorted(agents, key=lambda a: a["name"])},
        sort_keys=False, default_flow_style=False, allow_unicode=True,
    )
    open(path, "w").write(HEADER + body)


def find(agents, name):
    return next((a for a in agents if a.get("name") == name), None)


def purpose_line(agent_yaml_path):
    cfg = yaml.safe_load(open(agent_yaml_path)) or {}
    purpose = str(cfg.get("purpose") or "").strip()
    if not purpose:
        sys.exit(f"{agent_yaml_path}: no purpose field to distill")
    return purpose.splitlines()[0].strip()


def opt(flag):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else None


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__.strip())
    path, cmd, name = sys.argv[1], sys.argv[2], sys.argv[3]
    agents = load(path)
    entry = find(agents, name)
    today = datetime.date.today().isoformat()

    if cmd == "upsert":
        purpose = purpose_line(opt("--purpose-from") or sys.exit("upsert needs --purpose-from"))
        if entry is None:
            entry = {"name": name}
            agents.append(entry)
        entry["status"] = "active"
        entry["created"] = entry.get("created") or opt("--created") or today
        entry["purpose"] = purpose
        entry.pop("retired", None)
    elif cmd == "set-purpose":
        if entry is None:
            sys.exit(f"no registry entry for {name} — run create-agent.sh first")
        entry["purpose"] = purpose_line(opt("--purpose-from") or sys.exit("set-purpose needs --purpose-from"))
    elif cmd == "retire":
        if entry is None:
            sys.exit(f"no registry entry for {name} — that's drift; see list-agent.sh")
        if entry.get("status") == "retired":
            sys.exit(f"{name} is already retired ({entry.get('retired')})")
        entry["status"] = "retired"
        entry["retired"] = today
    elif cmd == "get":
        if entry is None:
            sys.exit(1)
        print(entry.get(sys.argv[4], ""))
        return
    else:
        sys.exit(f"unknown command: {cmd}")
    save(path, agents)


if __name__ == "__main__":
    main()
