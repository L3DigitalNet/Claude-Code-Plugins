# Postfix Documentation

## Official — postfix.org

- Main documentation index: https://www.postfix.org/documentation.html
- `main.cf` parameter reference (all directives): https://www.postfix.org/postconf.5.html
- `master.cf` reference (daemon table): https://www.postfix.org/master.5.html
- Postfix overview and architecture: https://www.postfix.org/OVERVIEW.html
- SASL howto: https://www.postfix.org/SASL_README.html
- TLS readme: https://www.postfix.org/TLS_README.html
- Virtual domain hosting: https://www.postfix.org/VIRTUAL_README.html
- Address rewriting: https://www.postfix.org/ADDRESS_REWRITING_README.html
- Postmaster guide (recommended reading before going live): https://www.postfix.org/POSTMASTER_README.html
- Debugging guide: https://www.postfix.org/DEBUG_README.html
- Access control lists: https://www.postfix.org/SMTPD_ACCESS_README.html
- Relay and access policies: https://www.postfix.org/SMTPD_POLICY_README.html
- Lookup table types: https://www.postfix.org/DATABASE_README.html

## Distribution-Specific Guides

- Arch Linux wiki (comprehensive, distro-agnostic in practice): https://wiki.archlinux.org/title/Postfix
- Ubuntu community help: https://help.ubuntu.com/community/Postfix
- RHEL/Fedora mail server guide: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/deploying_mail_servers/index
- Debian reference — mail transport agents: https://www.debian.org/doc/manuals/debian-reference/ch-net-smtp.en.html

## Deliverability and DNS

- MXToolbox (blacklist check, MX lookup, DMARC, SPF test): https://mxtoolbox.com/SuperTool.aspx
- Mail-tester.com (send a test email and get a deliverability score): https://www.mail-tester.com
- Google Postmaster Tools (monitor reputation for Gmail delivery): https://postmaster.google.com
- SPF record syntax reference: https://www.openspf.org/SPF_Record_Syntax
- DMARC overview and record builder: https://dmarcanalyzer.com
- Check TLS support to any mail server: https://checktls.com

## Man Pages

- `man postconf` — query and set configuration parameters
- `man postfix` — service control (start, stop, reload, check)
- `man postqueue` — queue management (flush, list)
- `man postsuper` — queue manipulation (delete, hold, requeue)
- `man postcat` — view queued message content
- `man postmap` — build and query lookup tables
- `man newaliases` — rebuild /etc/aliases database
- `man sendmail` — submit mail from command line (Postfix's sendmail-compatible wrapper)
