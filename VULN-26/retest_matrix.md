# Retest matrix — unauthenticated SQL via GetTiFlashSystemTable

Fresh run 2026-09-09T17:44:55Z against a live cluster (pd v26.3.4, tikv v8.5.8,
tidb v26.3.10, tiflash v26.3.11 ASan @ 3e5d8f8f). Post-reboot re-verification
2026-09-10T01:35:47Z produced identical results.

| Statement | Result |
|---|---|
| system.dt_tables | OK, 4802 bytes |
| system.databases | OK, 1498 bytes, full db inventory incl. mysql/sys/secaudit mappings |
| system.numbers LIMIT 3 | OK, 245 bytes |
| system.one | OK, 187 bytes |
| system.columns | OK, 1046 bytes, full column schemas |
| system.processes | OK, 1920 bytes, other queries' text + client IPs |
| system.settings | OK, 28628 bytes, full engine config |
| system.metrics | OK, 393 bytes |
| system.build_options | OK, 533 bytes |
| system.dt_segments | OK, 2957 bytes |
| same probe via host LAN address | OK — remotely reachable with default 0.0.0.0 binding |
| neg control: user rows by TiDB name | REJECTED "Database secaudit doesn't exist" |
| neg control: currentUser() | REJECTED "Unknown function currentUser" |
| system.numbers without LIMIT | client 30s deadline exceeded; tiflash remained alive and still served MySQL-path queries afterward (component survived — no crash claim) |
