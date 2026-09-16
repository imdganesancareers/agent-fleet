# 03 — Clean up aruvii-developer's workspace before cutover

Type: task
Status: open

## Question

`aruvii-developer`'s workspace on this VM has one untracked file
(`docker-compose-dev.yaml`) and is 5 commits behind its own remote
(`master...origin/master [behind 5]`); the other 3 agent workspaces are
clean. Since the new VM gets a fresh `git clone` (not a copy of this
workspace — see [Workspace state decision](../map.md)), anything not
committed and pushed here is lost at cutover. Decide per item: commit and
push `docker-compose-dev.yaml`, or discard it; pull the 5 upstream commits
so the working tree matches remote intent, or confirm being behind is fine
to just leave (the fresh clone on the new VM will track `origin/master`
regardless of this VM's state).
