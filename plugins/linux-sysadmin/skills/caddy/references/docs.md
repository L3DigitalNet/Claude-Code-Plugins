# Caddy Documentation

## Official

- Main docs: https://caddyserver.com/docs/
- Caddyfile concept and syntax: https://caddyserver.com/docs/caddyfile
- Caddyfile directives reference: https://caddyserver.com/docs/caddyfile/directives
- JSON config structure reference: https://caddyserver.com/docs/json/
- Automatic HTTPS overview: https://caddyserver.com/docs/automatic-https
- ACME challenge types (HTTP-01, TLS-ALPN-01, DNS-01): https://caddyserver.com/docs/automatic-https#acme-challenges
- TLS configuration options: https://caddyserver.com/docs/caddyfile/directives/tls
- Admin API reference: https://caddyserver.com/docs/api
- xcaddy plugin build system: https://github.com/caddyserver/xcaddy
- Download page (pick modules, get custom binary): https://caddyserver.com/download

## Installation

- Install guide (all distros): https://caddyserver.com/docs/install
- Official Debian/Ubuntu repo: https://caddyserver.com/docs/install#debian-ubuntu-raspbian
- Fedora/RHEL/CentOS repo: https://caddyserver.com/docs/install#fedora-redhat-centos
- Docker image: https://hub.docker.com/_/caddy

## Key Directives

- `reverse_proxy`: https://caddyserver.com/docs/caddyfile/directives/reverse_proxy
- `file_server`: https://caddyserver.com/docs/caddyfile/directives/file_server
- `php_fastcgi`: https://caddyserver.com/docs/caddyfile/directives/php_fastcgi
- `encode` (compression): https://caddyserver.com/docs/caddyfile/directives/encode
- `header`: https://caddyserver.com/docs/caddyfile/directives/header
- `redir`: https://caddyserver.com/docs/caddyfile/directives/redir
- `basicauth`: https://caddyserver.com/docs/caddyfile/directives/basicauth
- `log`: https://caddyserver.com/docs/caddyfile/directives/log
- `handle` / `handle_path`: https://caddyserver.com/docs/caddyfile/directives/handle

## Community and Third-Party

- Community forum: https://caddy.community/
- Third-party DNS provider modules (for DNS-01 wildcard certs): https://github.com/caddy-dns
- Caddy module registry (third-party plugins): https://caddyserver.com/docs/modules/
- caddy-docker-proxy (auto-proxy Docker containers via labels): https://github.com/lucaslorentz/caddy-docker-proxy
- caddy-ratelimit plugin: https://github.com/mholt/caddy-ratelimit
- Coraza WAF module: https://github.com/corazawaf/coraza-caddy

## Man Pages

- `man caddy` (if installed via package manager)
- `caddy help` — built-in command reference
- `caddy help <command>` — detailed help per subcommand
