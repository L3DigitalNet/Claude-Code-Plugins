#!/bin/bash
# Create known test state inside the container.
# Run once after container starts and systemd finishes booting.
set -euo pipefail

echo "=== Setting up test fixtures ==="

# ── Cron fixtures ──────────────────────────────────────────
echo "0 * * * * /bin/true # test-hourly" | crontab -u testadmin -
echo "[fixtures] cron: test-hourly entry added"

# ── Firewall fixtures ──────────────────────────────────────
if systemctl is-active firewalld &>/dev/null; then
    firewall-cmd --add-port=8080/tcp --permanent 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "[fixtures] firewall: port 8080/tcp added"
else
    echo "[fixtures] firewall: firewalld not running, skipping"
fi

# ── User/group fixtures ───────────────────────────────────
id testuser-fixture &>/dev/null || useradd -m testuser-fixture
getent group testgroup-fixture &>/dev/null || groupadd testgroup-fixture
echo "[fixtures] users: testuser-fixture and testgroup-fixture created"

# ── SSH fixtures ──────────────────────────────────────────
TESTADMIN_SSH="/home/testadmin/.ssh"
mkdir -p "$TESTADMIN_SSH"
if [ ! -f "$TESTADMIN_SSH/id_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$TESTADMIN_SSH/id_ed25519" -N "" -q
fi
chown -R testadmin: "$TESTADMIN_SSH"
chmod 700 "$TESTADMIN_SSH"
echo "[fixtures] ssh: testadmin key generated"

# ── Log fixtures ──────────────────────────────────────────
logger -t test-fixture "Self-test log entry for search validation"
echo "[fixtures] logs: test-fixture entry logged"

# ── Backup target directory ───────────────────────────────
mkdir -p /var/backups/linux-sysadmin
echo "[fixtures] backup: /var/backups/linux-sysadmin created"

# ── Documentation directory ───────────────────────────────
mkdir -p /tmp/sysadmin-docs
echo "[fixtures] docs: /tmp/sysadmin-docs created"

# ── Package fixture (install cowsay for pkg_remove tests) ──
dnf -y install cowsay 2>/dev/null || echo "[fixtures] packages: cowsay not available, skipping"

echo "=== Fixtures complete ==="
