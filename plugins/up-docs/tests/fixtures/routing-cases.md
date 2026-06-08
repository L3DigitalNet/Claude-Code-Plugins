# Routing cases (up-docs fast-path) — expected layer tags

| # | Session item | Expected layers |
|---|---|---|
| 1 | CLI flag `--verbose` added to a repo tool | repo |
| 2 | Service procedure / config path / env-var name documented | wiki |
| 3 | New monitoring service added to the homelab stack (strategic) | notion |
| 4 | OpenBao listener rebind (`BAO_ADDR` 127.0.0.1 → 100.90.121.89) | wiki (+repo if credentials.md cites it) |
| 5 | Secret PATH rotation (OpenBao path moved) — reference only, not the value | repo (credentials.md) (+wiki if referenced) |
| 6 | DNS A-record value changed (record-only inventory) | none (Pi-hole/Porkbun is system-of-record) |
| 7 | Secret VALUE changed in OpenBao | none (OpenBao is system-of-record) |
| 8 | New service added: deploy steps + strategic note + repo README | all (repo + wiki + notion) |
| 9 | Ambiguous "updated the auth setup" with no detail | all (fail-open) |

> Row 4 vs 5: a listener/bind ADDRESS is a config value → implementation-reference (wiki). A secret PATH or VALUE is credential/system-of-record-owned → repo reference (row 5) or none (rows 6–7). The matrix's credential-reference "env-var name" example means a secret's name, not every BAO_ADDR-style config var.
