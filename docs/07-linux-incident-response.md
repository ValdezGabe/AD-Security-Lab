# 07 — Linux Incident Response

Live-response triage on a compromised Linux host.

A Wazuh agent was deployed to the affected machine for centralized telemetry, but the
exercise was specifically about native live-response technique — the commands you use when
you're on the box and need answers before you can pull a disk image.

---

## Active sessions

**TTY vs PTS** — worth knowing which you're looking at. A TTY is a physical or virtual
console session. A PTS (pseudo-terminal slave) is a terminal emulator or, more relevantly,
a *remote* session. An unexpected PTS is an unexpected remote connection.

```bash
who              # currently logged in
w                # logged in + what each session is running
last             # login history, including logouts and reboots
ps -ft pts/1     # PID backing a specific terminal session
```

`w` is usually the highest-value first command — it gives you the user, source address,
idle time, and current process in one view.

Terminating sessions:

```bash
kill <PID>              # by process ID
pkill -9 -u <username>  # everything owned by a user
pkill -t pts/1          # everything attached to a terminal
```

---

## Network connections

```bash
ss -plant
```

Broken down: `-p` shows the owning process, `-l` listening sockets, `-a` all sockets,
`-n` numeric (skip DNS resolution, which is both faster and avoids tipping off an
attacker who's watching DNS), `-t` TCP.

The process attribution from `-p` is what matters — a connection is only interesting once
you know what's holding it open.

```bash
netstat -plant   # legacy equivalent; slower, often not installed by default
```

Worth knowing `netstat` exists because you'll hit older systems where it's all you have.

---

## Processes

```bash
ps -aux          # every process, all users, with the invoking command
pstree -p        # parent/child hierarchy with PIDs
```

`pstree` is the one that surfaces attack chains. A shell parented to a web server process,
or a network utility parented to a document viewer, is immediately wrong in a way that a
flat `ps` listing doesn't make obvious.

```bash
sudo fatrace     # live file access monitoring (not installed by default)
```

`fatrace` is the Linux analogue of Procmon — it shows which processes are touching which
files in real time. Useful for catching activity that isn't reflected anywhere in a
process listing.

---

## Logs

```bash
tail -f /var/log/syslog    # follow general system log
journalctl -xe             # recent events, with explanatory text
journalctl -u ssh --since "1 hour ago"
```

`journalctl -xe` is the fast orientation command — `-x` adds explanatory context to
messages, `-e` jumps to the end.

---

## Triage order

The sequence matters, because the most volatile evidence is lost first:

1. **`w` / `who`** — who's connected right now
2. **`ss -plant`** — what's talking, and what owns it
3. **`ps -aux` / `pstree -p`** — what's running, and what spawned it
4. **`journalctl` / `/var/log/syslog`** — how it got there
5. **Kill sessions and processes** — only after the above is captured

Killing first is the common instinct and the wrong one. The moment you terminate a session
you lose its process tree, its open sockets, and its file handles. Capture, then contain.

---

## Notes

**Everything above is running on a potentially compromised system.** A rootkit can hide
processes from `ps` and sockets from `ss`. Live response gets you a fast picture, not a
trustworthy one. Anything requiring real confidence needs a memory capture and offline
analysis.

**Wazuh's role here** is that agent telemetry is forwarded off-host, so it survives both
attacker cleanup and any tampering with local tooling. Same argument as the Windows
investigation in [docs/06](06-windows-incident-response.md) — centralized logging is what
you have left after the attacker deletes their tracks.
