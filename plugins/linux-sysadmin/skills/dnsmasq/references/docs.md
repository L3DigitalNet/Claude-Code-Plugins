# dnsmasq Documentation

## Official
- Man page (online): https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
- Project page and downloads: https://thekelleys.org.uk/dnsmasq/doc.html
- dnsmasq FAQ: https://thekelleys.org.uk/dnsmasq/docs/FAQ
- Changelog: https://thekelleys.org.uk/dnsmasq/CHANGELOG

## Distribution-Specific
- Arch Linux wiki (thorough coverage of config, DNSSEC, and NM integration): https://wiki.archlinux.org/title/dnsmasq
- Debian wiki: https://wiki.debian.org/dnsmasq
- Ubuntu — NetworkManager + dnsmasq plugin: https://ubuntu.com/server/docs/network-configuration (search "dnsmasq")

## NetworkManager Integration
- NM `dns=dnsmasq` plugin (per-connection split DNS): https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html
- Coexistence with systemd-resolved: https://wiki.archlinux.org/title/NetworkManager#dnsmasq

## systemd-resolved Conflict (Ubuntu/Debian)
- Disabling the stub listener: https://www.freedesktop.org/software/systemd/man/resolved.conf.html
- `DNSStubListener=no` in `/etc/systemd/resolved.conf`, then `systemctl restart systemd-resolved`

## Man pages
- `man dnsmasq`
- `man 5 dnsmasq` (config file format, if packaged separately)
