# rsync Documentation

## Man Pages

- `man rsync` — full flag reference, filter rules, exit codes, itemize-changes format
- `man rsyncd.conf` — daemon configuration: modules, auth, access control, logging

## Official

- rsync project site: https://rsync.samba.org/
- rsync source and releases: https://github.com/RsyncProject/rsync
- rsync documentation index: https://rsync.samba.org/documentation.html
- How rsync works (algorithm overview): https://rsync.samba.org/how-rsync-works.html
- The rsync algorithm (Tridgell & Mackerras paper): https://rsync.samba.org/tech_report/

## Usage References

- rsync examples (official): https://rsync.samba.org/examples.html
- DigitalOcean — How To Use Rsync to Sync Files: https://www.digitalocean.com/community/tutorials/how-to-use-rsync-to-sync-local-and-remote-directories
- rsync filter rules (include/exclude logic): https://download.samba.org/pub/rsync/rsync.1#FILTER_RULES

## Exit Codes

Full list is in `man rsync` under "EXIT VALUES". The most operationally relevant:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Syntax or usage error |
| 11 | Error in file I/O |
| 23 | Partial transfer — some files could not be transferred |
| 24 | Partial transfer — source files vanished during transfer |
| 255 | Unexplained error (often SSH connection failure) |

Codes 23 and 24 are often treated as acceptable in scripts when transferring from live filesystems.
