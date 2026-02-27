#!/usr/bin/env bash
# Creates and seeds the test.kdbx database for integration tests.
# Password: testpassword, no YubiKey.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="$SCRIPT_DIR/test.kdbx"

rm -f "$DB"

echo -e "testpassword\ntestpassword" | keepassxc-cli db-create --set-password "$DB"

# Create groups
for group in "Servers" "SSH Keys" "API Keys"; do
    echo "testpassword" | keepassxc-cli mkdir "$DB" "$group"
done

# Seed Servers group
echo -e "testpassword\nwebpass123" | keepassxc-cli add "$DB" "Servers/Web Server" \
    --username admin --url "https://web.example.com" --password-prompt
echo -e "testpassword\ndbpass456" | keepassxc-cli add "$DB" "Servers/DB Server" \
    --username dba --url "https://db.example.com" --password-prompt
echo -e "testpassword\noldpass" | keepassxc-cli add "$DB" "Servers/[INACTIVE] Old Server" \
    --username legacy --url "https://old.example.com" --password-prompt

# Seed SSH Keys group
echo -e "testpassword\nkeypass1" | keepassxc-cli add "$DB" "SSH Keys/SSH - webserver" \
    --username root --password-prompt
echo -e "testpassword\nkeypass2" | keepassxc-cli add "$DB" "SSH Keys/SSH - dbserver" \
    --username deploy --password-prompt

# Seed API Keys group
echo -e "testpassword\nsk-ant-test123" | keepassxc-cli add "$DB" "API Keys/Anthropic API - main" \
    --username apikey --url "https://api.anthropic.com" --password-prompt
echo -e "testpassword\nBSA-test456" | keepassxc-cli add "$DB" "API Keys/Brave Search API - dev" \
    --username apikey --url "https://api.search.brave.com" --password-prompt

echo "Test database created at $DB"
