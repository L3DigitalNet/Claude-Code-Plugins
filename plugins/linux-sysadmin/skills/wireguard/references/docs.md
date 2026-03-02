# WireGuard Documentation References

## Official

- [wireguard.com](https://www.wireguard.com/) — project home, whitepaper, and conceptual overview
- [WireGuard Quickstart](https://www.wireguard.com/quickstart/) — official getting-started guide covering key generation and basic peer setup
- [wg(8) and wg-quick(8) man pages](https://www.wireguard.com/xplatform/) — cross-platform tool reference; also available locally via `man wg` and `man wg-quick`

## Community Guides

- [Arch Linux Wiki: WireGuard](https://wiki.archlinux.org/title/WireGuard) — the most comprehensive single-page reference; covers setup, routing, DNS, split tunnel, and troubleshooting in detail; distro-agnostic despite the source
- [DigitalOcean: How To Set Up WireGuard on Ubuntu 22.04](https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-ubuntu-22-04) — step-by-step server and client setup with UFW and IPv6 coverage

## Tools

- [AllowedIPs Calculator (procustodibus.com)](https://www.procustodibus.com/blog/2021/03/wireguard-allowedips-calculator/) — generate CIDR lists for split-tunnel scenarios, including "everything except" patterns
- [wg-easy](https://github.com/wg-easy/wg-easy) — Docker-based web UI for managing WireGuard peers; useful for teams that need non-CLI peer management
