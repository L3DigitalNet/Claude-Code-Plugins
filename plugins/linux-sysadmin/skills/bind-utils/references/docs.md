# bind-utils / dnsutils Documentation

## Man Pages
- `man dig` — complete flag, output section, and query option reference
- `man nslookup` — nslookup usage and interactive mode
- `man host` — host command flags and output
- `man resolv.conf` — local resolver configuration (/etc/resolv.conf)
- `man nsswitch.conf` — name service switch configuration (controls lookup order)

## Official Documentation
- BIND 9 (the project that provides dig/nslookup/host): https://www.isc.org/bind/
- BIND 9 Administrator Reference Manual: https://bind9.readthedocs.io/
- dig manual page (online): https://linux.die.net/man/1/dig

## DNS Standards (RFCs)
- RFC 1034 — Domain names: concepts and facilities: https://www.rfc-editor.org/rfc/rfc1034
- RFC 1035 — Domain names: implementation and specification: https://www.rfc-editor.org/rfc/rfc1035
- RFC 4035 — DNSSEC protocol modifications: https://www.rfc-editor.org/rfc/rfc4035
- RFC 7208 — SPF for authorizing use of domains in email: https://www.rfc-editor.org/rfc/rfc7208
- RFC 6376 — DomainKeys Identified Mail (DKIM): https://www.rfc-editor.org/rfc/rfc6376
- RFC 7489 — DMARC: https://www.rfc-editor.org/rfc/rfc7489

## Distro Packages
- Debian/Ubuntu: `apt install bind9-dnsutils` (provides dig, nslookup, host, nsupdate)
- Fedora/RHEL: `dnf install bind-utils`
- Arch Linux: `pacman -S bind` (includes all tools)

## Useful External References
- DNS record type reference: https://en.wikipedia.org/wiki/List_of_DNS_record_types
- MXToolbox (web-based DNS, MX, SPF, DMARC checker): https://mxtoolbox.com/
- DMARC analyzer: https://dmarcian.com/dmarc-tools/
- DKIM validator: https://dkimvalidator.com/
- SPF record syntax and tester: https://dmarcian.com/spf-survey/
- DNSSEC debugger: https://dnssec-debugger.verisignlabs.com/
- DNS propagation checker: https://dnschecker.org/
- Public DNS resolvers list: https://dnsprivacy.org/public_resolvers/
- Arch Linux DNS wiki: https://wiki.archlinux.org/title/Domain_name_resolution
