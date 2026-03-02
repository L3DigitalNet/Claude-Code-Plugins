# mtr Documentation

## Man Pages
- `man mtr` — complete flag reference and output format description
- `man traceroute` — classic traceroute for comparison and context
- `man ping` — ICMP ping behavior reference

## Official Documentation
- mtr GitHub repository: https://github.com/traviscross/mtr
- mtr README: https://github.com/traviscross/mtr/blob/master/README.md
- mtr CHANGELOG: https://github.com/traviscross/mtr/blob/master/CHANGES

## Distro Packages
- Ubuntu package (mtr-tiny vs mtr): https://packages.ubuntu.com/search?keywords=mtr
  - `mtr-tiny`: minimal, no X11 dependency, suitable for servers
  - `mtr`: full version with optional GTK GUI
- Fedora/RHEL: `dnf install mtr` (includes both CLI and optional GUI)
- Arch Linux mtr wiki: https://wiki.archlinux.org/title/Network_Debugging#mtr

## Useful External References
- Interpreting mtr output (Matt Simerson): https://www.bitwizard.nl/mtr/
- Understanding ICMP rate limiting and mtr false positives: https://www.nanog.org/sites/default/files/mon.tutorial.doering.mtr.pdf
- BGP/AS number lookup (cymru): https://www.team-cymru.com/ip-asn-mapping
- Public looking glasses for comparing traces: https://www.bgp4.as/looking-glasses
- Hurricane Electric looking glass: https://lg.he.net/
- RIPE NCC looking glasses: https://www.ripe.net/analyse/archived-projects/ris-raw-data/ris-looking-glasses
