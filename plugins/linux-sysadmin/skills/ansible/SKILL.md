---
name: ansible
description: >
  Ansible agentless automation and configuration management: playbooks,
  inventory, ad-hoc commands, roles, collections, vault, and ansible-galaxy.
  MUST consult when installing, configuring, or troubleshooting ansible.
triggerPhrases:
  - "ansible"
  - "ansible-playbook"
  - "ansible-vault"
  - "ansible-galaxy"
  - "ansible-inventory"
  - "ansible-lint"
  - "ansible.cfg"
  - "playbook"
  - "inventory"
  - "roles"
  - "become"
  - "tasks"
  - "handlers"
  - "group_vars"
  - "host_vars"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binaries** | `ansible`, `ansible-playbook`, `ansible-vault`, `ansible-galaxy`, `ansible-inventory`, `ansible-lint` |
| **System config** | `/etc/ansible/ansible.cfg` |
| **User config** | `~/.ansible.cfg` (overrides system config) |
| **Default inventory** | `/etc/ansible/hosts` |
| **Roles path** | `/etc/ansible/roles` (system) · `~/.ansible/roles` (user) |
| **Collections path** | `~/.ansible/collections/` |
| **Type** | Agentless push-based automation (SSH for Linux, WinRM for Windows) |
| **Install** | `pip install ansible` / `apt install ansible` / `dnf install ansible` |

## Quick Start

```bash
sudo apt install ansible
ansible --version
ansible all -i "localhost," -m ping -c local
ansible-playbook playbook.yml --check --diff
```

## Key Operations

| Task | Command |
|------|---------|
| Ping all hosts | `ansible all -m ping` |
| Run playbook | `ansible-playbook playbook.yml` |
| Dry run (check + diff) | `ansible-playbook playbook.yml --check --diff` |
| Limit to hosts/group | `ansible-playbook playbook.yml --limit webservers` |
| Run by tag | `ansible-playbook playbook.yml --tags deploy` |
| Skip tags | `ansible-playbook playbook.yml --skip-tags slow` |
| Syntax check | `ansible-playbook playbook.yml --syntax-check` |
| Verbose output | `ansible-playbook playbook.yml -vvv` |
| Resume from task | `ansible-playbook playbook.yml --start-at-task "Deploy app"` |
| Ad-hoc shell | `ansible webservers -m shell -a "uptime"` |
| Ad-hoc package | `ansible all -m ansible.builtin.package -a "name=vim state=present" --become` |
| List inventory | `ansible-inventory --list` |
| Graph inventory groups | `ansible-inventory --graph` |
| Vault encrypt string | `ansible-vault encrypt_string 'secret' --name 'my_var'` |
| Vault edit file | `ansible-vault edit secrets.yml` |
| Galaxy install role | `ansible-galaxy install geerlingguy.nginx` |
| Galaxy install collection | `ansible-galaxy collection install community.general` |
| Install from requirements | `ansible-galaxy install -r requirements.yml` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}` | SSH key rejected, wrong user, or host unreachable | Verify `ansible_user` and `ansible_ssh_private_key_file`; test: `ssh -i key user@host` |
| `MODULE FAILURE\nrc=127\nmsg=The module failed...python` | `/usr/bin/python` missing on target (RHEL 8+, Ubuntu 22.04+) | Set `interpreter_python = auto_silent` in `[defaults]` or `ansible_python_interpreter=/usr/bin/python3` in inventory |
| `Missing sudo password` | `become: yes` but no `NOPASSWD` sudoers rule and no `-K` flag | Add `--ask-become-pass` (`-K`) or configure `NOPASSWD: ALL` for the ansible user in sudoers |
| `Vault secrets file not found: ...` | Wrong path to vault password file or vault ID mismatch | Verify `--vault-password-file` path; check `--vault-id` labels match between encrypt and decrypt |
| Task always shows `changed` | `shell` or `command` module used for idempotent operation | Replace with the appropriate idempotent module; or add `changed_when: false` where truly safe |
| `[WARNING]: Could not match supplied host pattern` | Host or group name not in inventory | Run `ansible-inventory --list` to see all available hosts and groups |
| `fatal: [host]: FAILED! => {"msg": "...is not a legal attribute..."}` | YAML indentation error or wrong module parameter name | Check indentation; run `ansible-playbook --syntax-check` |

## Pain Points

**Variable precedence has 16 levels.** `extra_vars` (`-e`) always wins; `host_vars` beats `group_vars`; role defaults lose to everything. The official precedence table should be bookmarked. When a variable "isn't working," precedence is the first thing to check.

**`command`/`shell` modules are not idempotent.** They always report `changed` unless you add `changed_when: false` or use `creates:`/`removes:` guards. Every time you reach for `shell:`, ask whether `ansible.builtin.copy`, `ansible.builtin.file`, `ansible.builtin.lineinfile`, or another native module covers the use case.

**`ansible_python_interpreter` on modern distros.** On RHEL 8+, Ubuntu 22.04+, and Fedora, the system Python is `/usr/bin/python3` but ansible may probe for `/usr/bin/python`. Set `interpreter_python = auto_silent` in `[defaults]` of `ansible.cfg` to suppress discovery warnings and auto-select the right interpreter.

**Handlers run once, at play end.** Multiple tasks notifying the same handler only trigger it once — which is correct — but execution is deferred until all tasks complete. If a service restart is needed mid-play before later tasks run, insert `meta: flush_handlers` to force immediate execution.

**SSH pipelining vs `requiretty`.** Enabling `pipelining = True` in `[ssh_connection]` reduces SSH round-trips substantially (5-10x faster for playbooks with many tasks), but it requires that `requiretty` is disabled in `/etc/sudoers` on target hosts. The fix: add `Defaults !requiretty` or a per-user `Defaults:ansible !requiretty` line.

**Collections vs roles.** Old-style `ansible-galaxy install` pulls roles into `~/.ansible/roles/`; new-style `ansible-galaxy collection install` pulls collections into `~/.ansible/collections/` and uses FQCNs (`community.general.ufw`, `ansible.posix.firewalld`). A `requirements.yml` can declare both `roles:` and `collections:` in separate sections. When a module "isn't found," the cause is almost always a missing collection rather than a missing role.

## See Also

- **systemd** — Service management and unit files; ansible's `systemd` module controls these
- **packer** — build VM images with Ansible provisioners before deployment
- **cloud-cli** — cloud platform CLIs for operations Ansible doesn't cover
- **vault** — secrets management; Ansible has a hashi_vault lookup plugin

## References

See `references/` for:
- `ansible.cfg.annotated` — full configuration file with every directive explained
- `playbook.yml.annotated` — annotated example playbook covering all major structures
- `common-patterns.md` — inventory formats, ad-hoc commands, roles, vault, galaxy, ansible-lint
- `docs.md` — official documentation links
