# Design: linux-sysadmin — ansible + restic Skills

**Date:** 2026-03-02
**Plugin:** `linux-sysadmin` (currently v1.0.0, 95 skills)
**Scope:** Add 2 new Tier 1 skills identified in the gap analysis

---

## Context

The gap analysis (`plugins/linux-sysadmin/docs/skill-inventory-and-gaps.md`) identified ansible as the single largest missing skill — the most widely used agentless configuration management tool, absent from a plugin that already covers systemd, cron, and a full monitoring stack. Restic was the top backup gap, frequently cited alongside borg but missing its own skill despite comparable adoption.

Both skills are independent and will be authored in parallel using two subagents.

---

## File Structure

```
plugins/linux-sysadmin/skills/
├── ansible/
│   ├── SKILL.md
│   └── references/
│       ├── ansible.cfg.annotated
│       ├── playbook.yml.annotated
│       ├── common-patterns.md
│       └── docs.md
└── restic/
    ├── SKILL.md
    └── references/
        ├── cheatsheet.md
        ├── common-patterns.md
        └── docs.md
```

---

## Ansible Skill

### SKILL.md

**Frontmatter triggers:** `ansible`, `ansible-playbook`, `ansible-vault`, `ansible-galaxy`, `ansible-inventory`, `ansible-lint`, `ansible.cfg`, `playbook`, `inventory`, `roles`, `become`

**Globs:** none (ansible files don't have a unique extension distinguishable from other YAML)

**Identity table:**

| Property | Value |
|----------|-------|
| Binaries | `ansible`, `ansible-playbook`, `ansible-vault`, `ansible-galaxy`, `ansible-inventory`, `ansible-lint` |
| System config | `/etc/ansible/ansible.cfg` |
| User config | `~/.ansible.cfg` |
| Default inventory | `/etc/ansible/hosts` |
| Roles path | `/etc/ansible/roles` (system) or `~/.ansible/roles` (user) |
| Collections path | `~/.ansible/collections/` |
| Type | Agentless push-based automation (SSH/WinRM) |
| Install | `pip install ansible` / `apt install ansible` / `dnf install ansible` |

**Key Operations:** ad-hoc ping, run playbook, check mode (`--check --diff`), limit hosts, run by tag, vault encrypt/decrypt/edit, galaxy role and collection install, inventory listing, syntax check.

**Common Failures:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| `UNREACHABLE` | SSH key not accepted or wrong user | Check `ansible_user`, `ansible_ssh_private_key_file`; test with `ssh -i key user@host` |
| `MODULE FAILURE` with Python path error | `/usr/bin/python` missing on target | Set `ansible_python_interpreter=/usr/bin/python3` or `auto_silent` in `ansible.cfg` |
| `Missing sudo password` | `become: yes` but no NOPASSWD and no `--ask-become-pass` | Add `-K` flag or configure `NOPASSWD` in sudoers |
| `Vault secrets file not found` | `--vault-password-file` path wrong or vault ID mismatch | Verify file path; check vault ID labels if using `--vault-id` |
| Task always shows `changed` | `shell`/`command` module used instead of idempotent module | Switch to a native module or add `changed_when: false` |

**Pain Points (expanded):**

1. **Variable precedence has 16 levels** — `extra_vars` (`-e`) always wins; `host_vars` beats `group_vars`; role defaults lose to everything. The [official precedence table](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence) should be bookmarked. When a variable "isn't working," precedence is the first thing to check.

2. **`command`/`shell` modules are not idempotent** — They always report `changed` unless you add `changed_when: false` or use `creates:`/`removes:` guards. Every time you reach for `shell:`, ask whether `ansible.builtin.copy`, `ansible.builtin.file`, `ansible.builtin.lineinfile`, or another native module covers the use case.

3. **`ansible_python_interpreter`** — On RHEL 8+, Ubuntu 22.04+, and Fedora, the default Python is `/usr/bin/python3` but ansible may try `/usr/bin/python`. Set `interpreter_python = auto_silent` in `[defaults]` to suppress discovery warnings and auto-select the right interpreter.

4. **Handlers run once, at play end** — Multiple tasks notifying the same handler only trigger it once (correct behavior), but that means handler execution is deferred. If an early task needs a service restarted before a later task runs, use `meta: flush_handlers` to force immediate execution.

5. **SSH pipelining speeds things up dramatically** — Enabling `pipelining = True` in `[ssh_connection]` reduces SSH round-trips but requires that target hosts have `requiretty` disabled in `/etc/sudoers`. The tradeoff: faster runs vs sudoers change required.

6. **Collections vs roles** — Old-style `ansible-galaxy install` pulls roles; new-style `ansible-galaxy collection install` pulls collections. Collections use FQCNs (`community.general.ufw`, `ansible.posix.firewalld`). A `requirements.yml` can declare both. Mixing them in a single file works but the syntax differs.

### References

**`ansible.cfg.annotated`** — annotated configuration covering:
- `[defaults]`: `inventory`, `roles_path`, `remote_user`, `private_key_file`, `host_key_checking`, `forks`, `timeout`, `log_path`, `interpreter_python`
- `[privilege_escalation]`: `become`, `become_method`, `become_user`, `become_ask_pass`
- `[ssh_connection]`: `pipelining`, `ssh_args` (ControlMaster/ControlPersist), `scp_if_ssh`
- `[diff]`: `always`, `context`

**`playbook.yml.annotated`** — a single annotated example playbook covering:
- Play-level: `hosts`, `become`, `gather_facts`, `vars`, `vars_files`
- Task structures: `name`, `module`, `register`, `debug`, `when`, `loop`
- `block` / `rescue` / `always` for error handling
- `notify` and `handlers`
- `tags` at play and task level
- `include_tasks` vs `import_tasks` (runtime vs parse-time)
- `pre_tasks` / `post_tasks`

**`common-patterns.md`** — organized by task:
- Static inventory (INI and YAML formats), dynamic inventory scripts
- Ad-hoc commands (ping, copy files, run commands, manage packages)
- Running playbooks (dry-run, tags, limits, verbosity levels)
- Role structure (`ansible-galaxy init`, directory layout, defaults vs vars)
- Ansible Vault (encrypt string, encrypt file, edit vault, vault-id workflow, using vault in playbooks)
- Galaxy and Collections (`requirements.yml` with roles and collections, offline install)
- `ansible-lint` usage and common rules

**`docs.md`** — links to official ansible documentation.

---

## Restic Skill

### SKILL.md

**Frontmatter triggers:** `restic`, `restic backup`, `restic restore`, `restic forget`, `restic prune`, `restic snapshots`, `restic init`, `restic check`, `restic mount`, deduplicating backup, encrypted backup

**Globs:** none

**Identity table:**

| Property | Value |
|----------|-------|
| Binary | `restic` |
| Unit | No daemon — run via cron or systemd timer |
| Config | No fixed path — driven by env vars (`RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`) or CLI flags |
| Supported backends | local, SFTP, S3/MinIO/Wasabi, Backblaze B2, REST server, Azure, GCS |
| Type | CLI backup tool (deduplication + encryption at rest) |
| Install | `apt install restic` / `dnf install restic` / `brew install restic` / binary from GitHub |

**Key Operations:** `restic init`, `restic backup`, `restic snapshots`, `restic restore`, `restic forget --keep-*`, `restic prune`, `restic check`, `restic mount`, `restic key list/add/remove`, `restic stats`, `restic unlock`

**Common Failures:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| `wrong password or no key found` | Incorrect password or wrong repo | Verify `RESTIC_REPOSITORY` and `RESTIC_PASSWORD`/`RESTIC_PASSWORD_FILE` |
| `Fatal: unable to open config file: ...is already locked` | Previous backup died holding a lock | `restic unlock` — verify no other backup is actually running first |
| `FUSE mount fails` | `fusermount` not available or permissions | `apt install fuse` / `dnf install fuse`; user must be in `fuse` group or run as root |
| S3: `403 Forbidden` | Wrong credentials or bucket policy | Check `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`; verify bucket exists and policy allows restic operations |
| `repository has unfinished operations` | Interrupted prune left partial pack files | `restic repair packs` then `restic prune` |

**Pain Points:**

1. **`forget` and `prune` are separate commands** — `restic forget --keep-daily 7` removes snapshot metadata but does NOT free disk space. You must run `restic prune` (or use `restic forget --prune`) afterwards. Many users run `forget` and wonder why disk usage doesn't drop.

2. **No recovery without the password** — Restic repos are encrypted with the password. There is no "forgot my password" recovery path. Store the password in a secrets manager (vaultwarden, keepass) and document the repo URL alongside it.

3. **`check` vs `check --read-data`** — `restic check` verifies the repo structure and metadata (fast). `restic check --read-data` actually reads and verifies every chunk against its hash (slow, can take hours for large repos). Run `--read-data` on a schedule, not after every backup.

4. **Exclude caches and temp dirs** — Without exclusions, restic backs up `~/.cache`, `/tmp`, node_modules, `.venv`, and browser caches. Use `--exclude-caches` (respects `CACHEDIR.TAG` files) and explicit `--exclude` patterns.

5. **Lock file deadlock with parallel runs** — Two simultaneous backups to the same repo will deadlock on the lock. Use systemd `Conflicts=` or a lock file guard in cron to prevent overlapping runs.

6. **Snapshot IDs are not stable** — Snapshot short IDs (8 hex chars) can collide as the repo grows. Scripts should use full 64-char IDs or the `latest` keyword (`restic restore latest`).

### References

**`cheatsheet.md`** — task-organized patterns:
- Initializing and configuring repos (local, SFTP, S3, REST)
- Backup with common exclude patterns
- Listing and filtering snapshots
- Restoring (full repo, single path, single file)
- Forget + prune retention policies
- Checking and repairing repos
- FUSE mount for browsing backups
- Key management (add/remove/rotate)
- Environment variable reference (`RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `RESTIC_PASSWORD_FILE`, `RESTIC_COMPRESSION`, backend-specific vars)

**`common-patterns.md`** — organized by backend and use case:
- **Local backend**: init, backup, restore, forget+prune, systemd timer
- **SFTP backend**: SSH key setup, connection string format, jump hosts
- **S3-compatible** (MinIO, Wasabi, AWS S3): credentials, endpoint override, bucket creation
- **Backblaze B2**: app key permissions, B2-specific env vars
- **REST server** (`rest-server`): running rest-server as a systemd service, `.htpasswd` auth, TLS via Caddy, connecting restic clients to it
- **Systemd timer for automated backups**: `backup.service` + `backup.timer` unit files, pre/post backup hooks, failure alerting
- **Retention policy examples**: daily/weekly/monthly/yearly patterns with `--keep-*` flags

**`docs.md`** — links to official restic documentation.

---

## Implementation Notes

- **Parallel authoring**: two subagents write ansible and restic simultaneously.
- **Review pass**: after both are written, check SKILL.md frontmatter YAML validity, confirm all `references/` files referenced in the SKILL.md `## References` section exist, and verify identity table format matches existing skills.
- **Version bump**: after skills are committed, bump `plugin.json` and `marketplace.json` from `1.0.0` to `1.1.0` and update `CHANGELOG.md`.

---

## Success Criteria

- [ ] `plugins/linux-sysadmin/skills/ansible/SKILL.md` exists and follows established format
- [ ] `plugins/linux-sysadmin/skills/ansible/references/` contains all 4 files
- [ ] `plugins/linux-sysadmin/skills/restic/SKILL.md` exists and follows established format
- [ ] `plugins/linux-sysadmin/skills/restic/references/` contains all 3 files
- [ ] All SKILL.md frontmatter parses as valid YAML
- [ ] `plugin.json` and `marketplace.json` bumped to `1.1.0`
- [ ] `CHANGELOG.md` updated with Added entries for both skills
- [ ] `./scripts/validate-marketplace.sh` passes
