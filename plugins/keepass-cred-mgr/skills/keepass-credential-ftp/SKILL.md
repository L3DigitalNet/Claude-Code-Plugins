---
name: keepass-credential-ftp
description: >
  FTP/SFTP credential handling. Use when storing, retrieving, or rotating FTP, FTPS, or SFTP credentials.
  Triggers on mentions of FTP, SFTP, file transfer, or lftp connection strings.
---

# FTP/SFTP Credential Handling

## FTP / FTPS

GROUP: Servers
TITLE FORMAT: FTP - <host>
REQUIRED FIELDS: username, password, url (host), port (if non-standard)
NOTES FIELD: protocol variant and lftp connection string

PROTOCOL VARIANTS:
- FTPS explicit: ftp+tls://user@host
- FTPS implicit: ftps://user@host
- Plain FTP: ftp://user@host <- SECURITY VIOLATION, see rule below

PLAIN FTP RULE: If the entry uses plain unencrypted FTP (no TLS), you MUST:
1. Flag this as a security concern to the user before storing
2. Require the user to provide a written explanation in the notes field
3. Do not store the entry without this note present

## SFTP

SFTP entries are split across two groups:

CONNECTION CREDENTIAL:
- Group: Servers
- Title: SFTP - <host>
- Fields: username, url (host), port (if non-standard)
- Notes: reference to the SSH Keys entry (e.g. "SSH key: SSH - <host>")

SSH KEY (handle per keepass-credential-ssh skill):
- Group: SSH Keys
- Title: SSH - <host>
- Notes: must reference back to the SFTP connection entry

lftp connection string: sftp://user@host
