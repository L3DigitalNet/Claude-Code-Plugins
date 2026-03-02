# Ansible Common Patterns

Each section is a complete, copy-paste-ready reference. Validate playbooks with
`ansible-playbook --syntax-check` and test changes with `--check --diff` before
applying to production hosts.

---

## 1. Inventory Formats

Ansible supports INI and YAML inventory formats. Both are equivalent — pick whichever
your team finds more readable. The YAML format scales better for large inventories
with many variables.

**INI format** (`/etc/ansible/hosts` or `inventory/hosts.ini`):

```ini
# Ungrouped hosts — belong to the implicit 'all' and 'ungrouped' groups
192.168.1.5
jumphost.example.com

# Named group
[webservers]
web01.example.com
web02.example.com ansible_port=2222    # Per-host variable override

# Another group
[dbservers]
db01.example.com
db02.example.com

# Group of groups — ':children' suffix makes a meta-group
[production:children]
webservers
dbservers

# Group variables applied to all hosts in [webservers]
[webservers:vars]
ansible_user=deploy
ansible_python_interpreter=/usr/bin/python3
http_port=80

# Host variables override group variables
[dbservers:vars]
ansible_user=dbadmin
mysql_max_connections=500
```

**YAML format** (`inventory/hosts.yml`):

```yaml
all:
  children:
    webservers:
      hosts:
        web01.example.com:
        web02.example.com:
          ansible_port: 2222           # Per-host variable
      vars:
        ansible_user: deploy
        http_port: 80

    dbservers:
      hosts:
        db01.example.com:
        db02.example.com:
      vars:
        ansible_user: dbadmin
        mysql_max_connections: 500

    production:
      children:
        webservers:
        dbservers:
```

For per-host or per-group variables that don't fit inline, use directory-based overrides
next to the inventory file:

```
inventory/
  hosts.yml
  host_vars/
    web01.example.com.yml    # Variables for web01 only
    db01.example.com.yml
  group_vars/
    webservers.yml           # Variables for all webservers
    dbservers.yml
    all.yml                  # Variables for every host
```

**Inspect the inventory:**

```bash
# Show all hosts and variables as JSON
ansible-inventory --list

# Show group hierarchy as a tree
ansible-inventory --graph

# Show variables for a specific host
ansible-inventory --host web01.example.com

# Use a non-default inventory file
ansible-inventory -i inventory/prod.yml --list
```

---

## 2. Ad-Hoc Commands

Ad-hoc commands run a single module without writing a playbook. Useful for quick
checks, one-off changes, and verifying connectivity before running a playbook.

```bash
# Connectivity check — uses the 'ping' module (not ICMP ping)
ansible all -m ping

# Ping a specific group
ansible webservers -m ping

# Run an arbitrary shell command
ansible webservers -m shell -a "uptime && df -h /"

# Run a command without a shell (safer — no shell expansion, no pipe support)
ansible all -m ansible.builtin.command -a "id"

# Copy a file to all hosts
ansible all -m ansible.builtin.copy -a "src=/tmp/config.txt dest=/etc/myapp/config.txt owner=root mode=0644" --become

# Delete a file
ansible webservers -m ansible.builtin.file -a "path=/tmp/stale.lock state=absent" --become

# Install a package (distro-agnostic)
ansible all -m ansible.builtin.package -a "name=vim state=present" --become

# Remove a package
ansible dbservers -m ansible.builtin.package -a "name=telnet state=absent" --become

# Start and enable a service
ansible webservers -m ansible.builtin.service -a "name=nginx state=started enabled=yes" --become

# Restart a service
ansible webservers -m ansible.builtin.service -a "name=nginx state=restarted" --become

# Gather all facts for a host (large output — pipe to grep or jq)
ansible web01.example.com -m setup

# Filter facts by key prefix
ansible web01.example.com -m setup -a "filter=ansible_distribution*"

# Get the OS family for all hosts
ansible all -m setup -a "filter=ansible_os_family"

# Run with a specific user and SSH key
ansible all -m ping --user deploy --private-key ~/.ssh/deploy_ed25519

# Prompt for become (sudo) password
ansible all -m shell -a "whoami" --become -K

# Limit to a subset of a group (comma-separated, or use a pattern)
ansible webservers -m ping --limit web01.example.com
ansible webservers -m ping --limit 'web01,web02'
```

---

## 3. Running Playbooks

Basic invocation with the most commonly used flags:

```bash
# Run a playbook against the default inventory
ansible-playbook playbook.yml

# Specify a custom inventory file
ansible-playbook -i inventory/prod.yml playbook.yml

# Dry run — show what would change without making changes
ansible-playbook playbook.yml --check

# Dry run with file diffs
ansible-playbook playbook.yml --check --diff

# Apply only to a specific host or group (can repeat --limit)
ansible-playbook playbook.yml --limit webservers
ansible-playbook playbook.yml --limit web01.example.com

# Run only tasks with a specific tag
ansible-playbook playbook.yml --tags deploy

# Run tasks with any of several tags
ansible-playbook playbook.yml --tags "deploy,config"

# Skip tasks with a specific tag
ansible-playbook playbook.yml --skip-tags slow

# Pass extra variables (highest precedence — overrides everything except task defaults)
ansible-playbook playbook.yml -e "app_version=2.5.0 env=staging"

# Extra vars from a file
ansible-playbook playbook.yml -e "@vars/override.yml"

# Verify YAML syntax without connecting to hosts
ansible-playbook playbook.yml --syntax-check

# Verbose output: -v (task results), -vv (+ connection debug), -vvv (+ SSH debug)
ansible-playbook playbook.yml -vvv

# List all tasks that would run (no execution)
ansible-playbook playbook.yml --list-tasks

# List all hosts the play would target
ansible-playbook playbook.yml --list-hosts

# Resume from a specific task name (useful after a failed run)
ansible-playbook playbook.yml --start-at-task "Deploy application"

# Re-run only on hosts that failed in a previous run (using the .retry file)
ansible-playbook playbook.yml --limit @playbook.retry

# Prompt for SSH password (when no key auth is configured)
ansible-playbook playbook.yml --ask-pass

# Prompt for become (sudo) password
ansible-playbook playbook.yml --ask-become-pass
```

---

## 4. Roles

Roles are the standard unit of reusability in Ansible. They bundle tasks, handlers,
templates, files, and variables into a self-contained directory structure that any
playbook can reference.

**Create a new role scaffold:**

```bash
ansible-galaxy init myrole
```

This creates the following structure:

```
myrole/
├── defaults/
│   └── main.yml      # Role defaults — LOWEST precedence; always overridable by any other variable source
├── vars/
│   └── main.yml      # Role variables — higher precedence than defaults; not meant to be overridden casually
├── tasks/
│   └── main.yml      # Entry point for the role's task list
├── handlers/
│   └── main.yml      # Handlers for this role (can be notified by any task in the play)
├── templates/
│   └── ...           # Jinja2 templates — referenced as src: templatename.j2 (no path needed)
├── files/
│   └── ...           # Static files — referenced as src: filename (no path needed)
├── meta/
│   └── main.yml      # Role metadata: dependencies, galaxy info, minimum ansible version
└── README.md
```

**Key distinction: `defaults/main.yml` vs `vars/main.yml`**

`defaults/main.yml` holds values you expect callers to override — they are the lowest
precedence variables in the entire system. `vars/main.yml` holds implementation details
that should stay fixed regardless of the caller's environment. If you want users to be
able to change a value with `group_vars` or `-e`, put it in `defaults/`. If it's an
internal constant, put it in `vars/`.

**Using roles in a playbook:**

```yaml
# Simple form — just name the role
- hosts: webservers
  roles:
    - common
    - nginx

# Parameterized form — override defaults for this invocation
- hosts: webservers
  roles:
    - role: nginx
      vars:
        nginx_worker_processes: 4
        nginx_listen_port: 443

# Conditional role application
- hosts: all
  roles:
    - role: firewalld
      when: ansible_os_family == "RedHat"
    - role: ufw
      when: ansible_os_family == "Debian"

# Roles can also be imported inside a tasks block (for ordering control)
- hosts: webservers
  tasks:
    - name: Run common setup
      ansible.builtin.import_role:
        name: common

    - name: Deploy config before nginx role
      ansible.builtin.template:
        src: myconfig.j2
        dest: /etc/myconfig.conf

    - name: Run nginx role after custom config is in place
      ansible.builtin.import_role:
        name: nginx
```

---

## 5. Ansible Vault

Vault encrypts secrets at rest inside your repository. Encrypted files are safe to
commit to version control — the encryption key never touches the repo.

```bash
# Create a new encrypted file
ansible-vault create secrets.yml

# Encrypt an existing plaintext file in-place
ansible-vault encrypt vars/secrets.yml

# Decrypt an encrypted file in-place (avoid — prefer 'view' or 'edit')
ansible-vault decrypt vars/secrets.yml

# Open an encrypted file in $EDITOR for editing
ansible-vault edit vars/secrets.yml

# View the decrypted contents without writing to disk
ansible-vault view vars/secrets.yml

# Re-key: change the vault password on an encrypted file
ansible-vault rekey vars/secrets.yml

# Encrypt a single string value for use as an inline variable
ansible-vault encrypt_string 'db_password_here' --name 'db_password'
# Output can be pasted directly into a vars file or group_vars:
# db_password: !vault |
#   $ANSIBLE_VAULT;1.1;AES256
#   ...
```

**Running playbooks with vault:**

```bash
# Prompt for the vault password interactively
ansible-playbook playbook.yml --ask-vault-pass

# Read the vault password from a file (for automation/CI)
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

# Use an executable script as the password source (e.g., fetch from a secrets manager)
ansible-playbook playbook.yml --vault-password-file scripts/get-vault-pass.sh
```

**Vault ID workflow (multiple vault passwords):**

Vault IDs let you label encrypted values so ansible knows which password to use for each.
Useful when different teams or environments use different encryption keys.

```bash
# Encrypt with a vault ID label
ansible-vault encrypt_string 'prod_secret' --name 'db_password' --vault-id prod@~/.vault_pass_prod
ansible-vault encrypt_string 'dev_secret'  --name 'db_password' --vault-id dev@~/.vault_pass_dev

# Run with multiple vault IDs
ansible-playbook playbook.yml \
  --vault-id prod@~/.vault_pass_prod \
  --vault-id dev@~/.vault_pass_dev
```

Store the vault password file path in `ansible.cfg` so you never need to pass it on
the command line:

```ini
[defaults]
vault_password_file = ~/.vault_pass
```

---

## 6. Galaxy and Collections

**ansible-galaxy** manages two separate artifact types with separate namespaces:

- **Roles**: single-purpose automation (old style); installed to `~/.ansible/roles/`
- **Collections**: namespaced packages containing modules, plugins, roles, and docs (new style); installed to `~/.ansible/collections/`

```bash
# Install a role from Galaxy
ansible-galaxy install geerlingguy.nginx

# Install a specific version of a role
ansible-galaxy install geerlingguy.nginx,3.2.0

# Install a collection (use FQCN: namespace.collection)
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.mysql

# Install a specific collection version
ansible-galaxy collection install community.general:==5.8.0

# List installed roles
ansible-galaxy list

# List installed collections
ansible-galaxy collection list

# Remove a role
ansible-galaxy remove geerlingguy.nginx
```

**`requirements.yml` — install everything at once:**

Both roles and collections can be declared in a single `requirements.yml` file.
Keep this file in version control alongside your playbooks.

```yaml
# requirements.yml
roles:
  - name: geerlingguy.nginx
    version: "3.2.0"

  - name: geerlingguy.postgresql
    version: "3.3.4"

  # Install a role directly from a git repo (no Galaxy required)
  - name: my_internal_role
    src: https://git.example.com/ansible-roles/my-role.git
    scm: git
    version: main

collections:
  - name: community.general
    version: ">=5.0.0"

  - name: ansible.posix
    version: "1.5.4"

  - name: community.mysql
```

```bash
# Install everything from requirements.yml
ansible-galaxy install -r requirements.yml

# Install collections declared in requirements.yml
ansible-galaxy collection install -r requirements.yml

# Force reinstall (update to latest matching versions)
ansible-galaxy install -r requirements.yml --force
```

After installing a collection, use its modules with their FQCN in playbooks:

```yaml
- name: Allow SSH through UFW
  community.general.ufw:
    rule: allow
    port: "22"
    proto: tcp

- name: Manage firewalld
  ansible.posix.firewalld:
    service: http
    permanent: yes
    state: enabled
```

---

## 7. ansible-lint

ansible-lint is a static analysis tool that catches common mistakes, style issues,
and deprecated patterns before you run a playbook against real hosts. Run it in CI
to enforce a consistent baseline across the team.

```bash
# Install
pip install ansible-lint

# Lint a specific playbook
ansible-lint playbook.yml

# Lint all playbooks and roles in the current directory
ansible-lint

# Show all available rules and their IDs
ansible-lint --list-rules

# Show only warnings (not errors)
ansible-lint --warn-list

# Output as JSON (for CI integration)
ansible-lint -f json playbook.yml
```

**`.ansible-lint` configuration file** (place at the project root):

```yaml
# .ansible-lint
# Profiles: min, basic, moderate, safety, shared, production
profile: moderate

# Rules to permanently skip (use IDs from ansible-lint --list-rules)
skip_list:
  - yaml[line-length]       # Line-length rule is often too strict for long module args
  - name[casing]            # Allow mixed-case task names

# Rules to treat as warnings instead of errors
warn_list:
  - experimental            # New rules still in beta

# Exclude directories from linting
exclude_paths:
  - .git/
  - molecule/
  - tests/

# Minimum severity level to report: blocker, critical, major, minor, info
# Only report issues at this level or above.
# severity: major
```

**Rules that trip people up most often:**

`no-changed-when` — fires on any `command` or `shell` task that doesn't set
`changed_when`. The fix is either `changed_when: false` (for pure read commands) or
`changed_when: result.rc == 0` tied to actual state changes.

`command-instead-of-module` — fires when `shell` or `command` is used where a native
module exists (e.g., using `shell: systemctl restart nginx` instead of
`ansible.builtin.service: state=restarted`). Native modules are idempotent; shell
invocations are not.

`no-free-form` — fires on tasks using the old free-form module syntax like
`ansible.builtin.command: echo hello`. Use the dictionary form instead:
`ansible.builtin.command: cmd: echo hello`.

`fqcn` — fires when modules are referenced by short name (`package:`) instead of
FQCN (`ansible.builtin.package:`). Short names are resolved at runtime and can
be ambiguous when multiple collections define modules with the same name.

```bash
# Suppress a specific rule for one task with a comment
- name: Run a legitimately non-idempotent command
  ansible.builtin.shell: /usr/local/bin/generate-one-time-token.sh
  changed_when: true
  # noqa: no-changed-when
```
