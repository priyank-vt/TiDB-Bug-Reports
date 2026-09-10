# PoC — TiDB `LOAD STATS` missing privilege check

Two files:

- `repro.sh` — self-contained. Downloads TiDB v8.5.1, starts it, exploits, verifies, cleans up.
  Exits **0 only if the vulnerability reproduces**.
- `evil.json` — the attacker payload. Hand-written; requires no privileged access to produce.

## Run

```bash
./repro.sh
echo $?  # 0 = reproduced
```

Requirements: linux x86_64, `curl`, `tar`, a `mysql`/`mariadb` client, ~1 GB disk.
No Docker, no cluster, no root.
