---
name: apache
description: >
  Apache HTTP Server administration: config syntax, virtual hosts, SSL/TLS,
  mod_rewrite, .htaccess, PHP-FPM, reverse proxy, access control, and
  troubleshooting.
  MUST consult when installing, configuring, or troubleshooting apache.
triggerPhrases:
  - "apache"
  - "httpd"
  - "apache2"
  - "mod_rewrite"
  - "mod_ssl"
  - "mod_proxy"
  - "mod_php"
  - ".htaccess"
  - "VirtualHost"
  - "AllowOverride"
  - "apachectl"
  - "sites-available"
  - "sites-enabled"
  - "a2ensite"
  - "a2enmod"
globs:
  - "**/httpd.conf"
  - "**/apache2.conf"
  - "**/sites-available/**"
  - "**/sites-enabled/**"
  - "**/*.htaccess"
last_verified: "unverified"
---

## Identity
- **Unit**: `apache2.service` (Debian/Ubuntu), `httpd.service` (RHEL/Fedora/CentOS)
- **Config (Debian)**: `/etc/apache2/apache2.conf`, `/etc/apache2/sites-available/`, `/etc/apache2/sites-enabled/`, `/etc/apache2/mods-available/`, `/etc/apache2/mods-enabled/`, `/etc/apache2/conf-available/`
- **Config (RHEL)**: `/etc/httpd/httpd.conf`, `/etc/httpd/conf.d/`, `/etc/httpd/conf.modules.d/`
- **Logs**: `journalctl -u apache2` / `journalctl -u httpd`, `/var/log/apache2/` (Debian), `/var/log/httpd/` (RHEL)
- **User**: `www-data` (Debian/Ubuntu), `apache` (RHEL/Fedora)
- **Distro install**: `apt install apache2` / `dnf install httpd`

## Quick Start
```bash
sudo apt install apache2
sudo systemctl enable --now apache2
sudo apachectl configtest        # Syntax OK = config valid
curl -sI http://localhost         # HTTP 200 = running
```

## Key Operations

| Task | Command | Command (RHEL) |
|------|---------|----------------|
| Status | `systemctl status apache2` | `systemctl status httpd` |
| Start | `sudo systemctl start apache2` | `sudo systemctl start httpd` |
| Stop | `sudo systemctl stop apache2` | `sudo systemctl stop httpd` |
| Reload (graceful) | `sudo systemctl reload apache2` | `sudo systemctl reload httpd` |
| Restart | `sudo systemctl restart apache2` | `sudo systemctl restart httpd` |
| Test config | `sudo apachectl configtest` | `sudo apachectl configtest` |
| Full config dump | `sudo apache2ctl -S` | `sudo httpd -S` |
| Enable site | `sudo a2ensite example.conf` | (symlink to `/etc/httpd/conf.d/`) |
| Disable site | `sudo a2dissite example.conf` | (remove symlink) |
| Enable module | `sudo a2enmod rewrite` | edit `/etc/httpd/conf.modules.d/` |
| Disable module | `sudo a2dismod rewrite` | comment out LoadModule line |
| List enabled modules | `apache2ctl -M` | `httpd -M` |
| Check open ports | `ss -tlnp \| grep apache2` | `ss -tlnp \| grep httpd` |
| Check vhost config | `apache2ctl -S` | `httpd -S` |
| Tail error log | `sudo tail -f /var/log/apache2/error.log` | `sudo tail -f /var/log/httpd/error_log` |
| Tail access log | `sudo tail -f /var/log/apache2/access.log` | `sudo tail -f /var/log/httpd/access_log` |
| Create htpasswd file | `htpasswd -c /etc/apache2/.htpasswd user` | `htpasswd -c /etc/httpd/.htpasswd user` |
| Add htpasswd user | `htpasswd /etc/apache2/.htpasswd user` | `htpasswd /etc/httpd/.htpasswd user` |
| Graceful stop | `sudo apachectl graceful-stop` | `sudo apachectl graceful-stop` |

## Expected State
- **Ports**: 80/tcp (HTTP), 443/tcp (HTTPS)
- **Verify**: `ss -tlnp | grep ':80\|:443'`
- **Firewall (Debian)**: `sudo ufw allow 'Apache Full'` or `sudo ufw allow 80,443/tcp`
- **Firewall (RHEL)**: `sudo firewall-cmd --add-service=http --add-service=https --permanent && sudo firewall-cmd --reload`
- **Loaded modules**: Verify with `apache2ctl -M` — expect `ssl_module`, `rewrite_module` for typical setups

## Health Checks
1. `systemctl is-active apache2` (or `httpd`) → `active`
2. `sudo apachectl configtest 2>&1` → contains `Syntax OK`
3. `curl -sI http://localhost` → HTTP response (not connection refused)
4. `ss -tlnp | grep ':80\|:443'` → apache2 or httpd listed

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `403 Forbidden` | Missing `Require all granted` or wrong file permissions | Check `Directory` block for `Require` directive; verify DocumentRoot permissions with `ls -la` |
| `404 Not Found` | DocumentRoot wrong path, or file doesn't exist | `apache2ctl -S` to confirm active vhost; verify path with `ls` |
| `Address already in use` on port 80/443 | Another process bound to the port | `ss -tlnp \| grep :80` — find and stop conflicting process (often another httpd or nginx) |
| `.htaccess not working` | `AllowOverride None` in the Directory block | Change to `AllowOverride All` or the specific directives needed; reload apache |
| `SSL handshake failure` / `ERR_SSL_PROTOCOL_ERROR` | mod_ssl not loaded, wrong cert path, or TLS version mismatch | `apache2ctl -M \| grep ssl`; verify cert paths; check SSLProtocol directive |
| `Permission denied` on files | Apache user (`www-data`/`apache`) can't read files | `chown -R www-data:www-data /var/www/mysite` or fix SELinux context (`restorecon -Rv /var/www/`) |
| `mod_rewrite not working` | Module not enabled, or AllowOverride not set | `a2enmod rewrite && systemctl reload apache2`; ensure `AllowOverride All` is set |
| Wrong VirtualHost matches requests | ServerName conflict or missing default vhost | `apache2ctl -S` to see vhost matching order; add `_default_` or explicit ServerName |
| `AH00558: Could not reliably determine server's FQDN` | ServerName not set globally | Add `ServerName localhost` to apache2.conf or the main httpd.conf |
| `413 Request Entity Too Large` | `LimitRequestBody` too small for uploads | Increase `LimitRequestBody` in the VirtualHost or Directory block |

## Pain Points
- **Debian vs RHEL config layout**: Debian uses `a2ensite`/`a2enmod` with `sites-available/` + `sites-enabled/` symlinks and separate `mods-available/`. RHEL puts everything in `conf.d/` with no enable/disable tooling — you manage files directly.
- **`.htaccess` performance cost**: Every request traverses all parent directories looking for `.htaccess` files when `AllowOverride` is anything but `None`. On high-traffic sites this is measurable overhead. Prefer `AllowOverride None` and put directives in the VirtualHost block directly.
- **ServerName ordering and default vhost selection**: Apache picks the first VirtualHost that matches the requested IP:port if no `ServerName` matches. Unlike nginx, there is no explicit `default_server` flag — the first defined vhost on a given port becomes the default. File load order (alphabetical in conf.d/ and sites-enabled/) determines which is first.
- **MPM selection (prefork vs worker vs event)**: `prefork` is required for `mod_php` but is single-threaded per process and memory-heavy. `worker` is multi-threaded but incompatible with non-thread-safe PHP. `event` (the default in modern Apache) is the best choice with PHP-FPM. Check with `apache2ctl -V | grep MPM`.
- **mod_php vs PHP-FPM**: `mod_php` embeds PHP into Apache (requires prefork MPM, loads PHP for every request including static files). PHP-FPM via `mod_proxy_fcgi` uses a separate process pool, works with event MPM, and lets you run multiple PHP versions. Prefer PHP-FPM for new deployments.
- **Graceful vs immediate restart**: `systemctl reload apache2` sends SIGUSR1 (graceful restart) — existing requests finish before workers restart. `systemctl restart apache2` sends SIGTERM, immediately killing all connections. Use reload for production config changes.
- **SELinux on RHEL**: If files have correct Unix permissions but Apache still gets `Permission denied`, SELinux is likely the cause. Check with `ausearch -c httpd --raw | audit2allow` and fix with `chcon -t httpd_sys_content_t` or a custom policy.

## See Also
- **nginx** — event-driven web server and reverse proxy, lighter memory footprint per connection
- **caddy** — modern web server with automatic HTTPS and zero-config TLS via ACME
- **traefik** — container-native reverse proxy with auto-discovery from Docker labels
- **haproxy** — high-performance TCP/HTTP load balancer for multi-backend routing
- **certbot** — free TLS certificates from Let's Encrypt for Apache and nginx

## References
See `references/` for:
- `httpd.conf.annotated` — complete server config and VirtualHost blocks with every directive explained
- `common-patterns.md` — VirtualHost, SSL, reverse proxy, PHP-FPM, htpasswd, rewrites, and static file examples
- `docs.md` — official documentation links
