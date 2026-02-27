---
name: keepass-credential-cpanel
description: >
  cPanel credential handling. Use when storing, retrieving, or rotating cPanel hosting credentials.
  Triggers on mentions of cPanel, hosting panel, WHM, or web hosting credentials.
---

# cPanel Credential Handling

GROUP: Servers
TITLE FORMAT: cPanel - <domain>
REQUIRED FIELDS: username, password, url (https://<domain>:2083)
NOTES: hosting provider name, all associated domains

ROTATION: rotate when access has been shared or revoked, or on hosting provider change.
