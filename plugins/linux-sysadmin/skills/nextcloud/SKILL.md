---
name: nextcloud
description: >
  Nextcloud self-hosted cloud file storage and collaboration platform:
  installation, occ CLI administration, background jobs, file scanning,
  app management, upgrades, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting nextcloud.
triggerPhrases:
  - "nextcloud"
  - "Nextcloud"
  - "nextcloud docker"
  - "nextcloud install"
  - "nextcloud occ"
  - "self-hosted cloud"
  - "nextcloud apps"
  - "occ maintenance:mode"
  - "occ files:scan"
  - "occ upgrade"
  - "nextcloud cron"
  - "nextcloud Redis"
globs:
  - "**/config/config.php"
  - "**/nextcloud.conf"
  - "**/nextcloud/**/*.conf"
last_verified: "unverified"
---

## Identity

- **Process model**: PHP web application — no single daemon. Runs under the web server's PHP-FPM worker pool. There is no `nextcloud.service` to restart.
- **CLI tool**: `occ` (located at the Nextcloud app root, e.g. `/var/www/nextcloud/occ`). Must be run as the web server user.
  - Docker: `docker compose exec --user www-data nextcloud php occ <command>`
  - Bare-metal: `sudo -u www-data php /var/www/nextcloud/occ <command>`
- **Config**: `<nextcloud-root>/config/config.php` — PHP array, not INI format
- **Data dir**: Set via `datadirectory` in `config.php`. Default: `<nextcloud-root>/data/`
- **Logs**: `<data-dir>/nextcloud.log` (JSON lines); also `journalctl -u php-fpm` and the web server error log
- **Recommended install method**: Docker Compose (avoids PHP/extension version conflicts)
- **Dependencies**: Web server (nginx or Apache) + PHP-FPM + MariaDB/PostgreSQL + Redis (required for file locking with multiple users)
- **Web server user**: `www-data` (Debian/Ubuntu), `apache` (RHEL/Fedora), or the container's `www-data`

## Quick Start

```bash
# Docker Compose (recommended)
docker compose pull
docker compose up -d
docker compose exec --user www-data nextcloud php occ status
# Bare-metal
sudo apt install php-fpm php-mysql php-redis php-gd php-intl php-zip
sudo -u www-data php /var/www/nextcloud/occ status
```

## Key Operations

| Task | Command |
|------|---------|
| Check system status | `occ status` |
| Check for upgrade | `occ update:check` |
| Enable maintenance mode | `occ maintenance:mode --on` |
| Disable maintenance mode | `occ maintenance:mode --off` |
| Run upgrade after files updated | `occ upgrade` |
| Run background cron manually | `occ background:cron` |
| Check background job mode | `occ background:cron` / `occ background:ajax` / `occ background:webcron` (shows current) |
| List all apps | `occ app:list` |
| Enable an app | `occ app:enable <appname>` |
| Disable an app | `occ app:disable <appname>` |
| Install an app | `occ app:install <appname>` |
| List users | `occ user:list` |
| Add a user | `occ user:add --password-from-env --display-name="Full Name" username` |
| Reset a user's password | `occ user:resetpassword username` |
| Delete a user | `occ user:delete username` |
| Scan files for one user | `occ files:scan username` |
| Scan all files | `occ files:scan --all` |
| Add missing DB indices | `occ db:add-missing-indices` |
| Add missing DB columns | `occ db:add-missing-columns` |
| Convert DB to big integers | `occ db:convert-filecache-bigint` |
| Clear opcode/data cache | `occ cache:clear` (app-level); restart PHP-FPM for OPcache |
| Check background job queue | `occ background:queue:status` |
| Run pending background jobs | `occ background:job:execute <job-id>` |
| Repair installation | `occ maintenance:repair` |
| Set a config value | `occ config:system:set key --value="value"` |
| Get a config value | `occ config:system:get key` |
| Check logs | `occ log:tail` or inspect `<data-dir>/nextcloud.log` |

## Expected State

- **Maintenance mode**: off (`occ status` shows `maintenance: false`)
- **Background jobs**: cron mode (`occ background:cron` is active); cron running every 5 minutes
- **Admin panel warnings**: none (check Settings → Administration → Overview)
- **Redis**: connected and used for file locking (visible in `config.php` as `memcache.locking`)
- **Data directory**: writable by the web server user

## Health Checks

1. `occ status` → `installed: true`, `maintenance: false`, `needsDbUpgrade: false`
2. `occ background:queue:status` → last job ran within the last 10 minutes
3. `curl -sI https://<hostname>/status.php` → `"installed":true` in JSON body
4. `occ db:add-missing-indices` → `Done` with no new indices added (confirms schema is current)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Your data directory is not readable by the server" | Wrong ownership or permissions on data dir | `chown -R www-data:www-data <data-dir>` and `chmod 750 <data-dir>` |
| "The PHP OPcache is not properly configured" | `opcache.memory_consumption` too low or `opcache.revalidate_freq` not 0 | Set `opcache.memory_consumption=128`, `opcache.revalidate_freq=0`, `opcache.save_comments=1` in `php.ini` |
| Redis connection failing / file locking errors | Redis not running, wrong socket path, or missing `php-redis` extension | `redis-cli ping`; verify `memcache.locking` config; check PHP redis extension is loaded |
| "Your installation has no default phone region set" | Missing `default_phone_region` in `config.php` | `occ config:system:set default_phone_region --value="US"` (or your country code) |
| Apps failing after major upgrade | App incompatible with new Nextcloud version | `occ app:disable <appname>`; check app store for compatible version; re-enable after update |
| Background cron not running | No system cron entry or cron container stopped | Verify `crontab -u www-data -l` or Docker cron service; check last run in admin panel |
| "Could not check if the .htaccess file is writable" | Data dir or Nextcloud root owned by root instead of www-data | `chown www-data:www-data /var/www/nextcloud/.htaccess` |
| Slow file listing / uploads | No Redis configured for memcache, or DB missing indices | Add `memcache.local` and `memcache.locking` Redis config; run `occ db:add-missing-indices` |
| 504 Gateway Timeout on large uploads | PHP `max_execution_time` or nginx `proxy_read_timeout` too low | Set `max_execution_time = 3600` in `php.ini`; add `proxy_read_timeout 3600;` in nginx config |
| "Server has no maintenance window start time configured" | Missing `maintenance_window_start` config | `occ config:system:set maintenance_window_start --type=integer --value=1` (hour in UTC) |

## Pain Points

- **Docker vs bare-metal**: Docker Compose is strongly preferred. Bare-metal requires matching exact PHP version, all required extensions (`gd`, `intl`, `zip`, `redis`, `imagick`, etc.), and correct `php.ini` settings. Debugging bare-metal installs is time-consuming; only pursue it if there is a specific reason.
- **occ must run as www-data**: Running `occ` as root causes file ownership changes that break the installation. Always use `sudo -u www-data php occ` or `docker compose exec --user www-data nextcloud php occ`.
- **Major version upgrades must be sequential**: Cannot upgrade from Nextcloud 27 to 29 directly. Must go 27 → 28 → 29, running `occ upgrade` at each step. Skipping versions leaves the DB in an inconsistent state.
- **Redis is required in multi-user installs**: Without Redis for file locking (`memcache.locking`), concurrent writes cause data corruption. The default `NoopLockingProvider` silently accepts all lock requests without actually locking.
- **Cron must be configured explicitly**: Out of the box, Nextcloud uses AJAX cron (triggered by user page loads). This is unreliable. Switch to system cron or use a dedicated cron container. Background jobs not running causes notification backlogs, activity feed issues, and share link expiry failures.
- **`occ upgrade` can be slow**: Upgrades on large installs (millions of files, many apps) can take 10–60 minutes. Always enable maintenance mode first. Do not interrupt mid-upgrade — partial upgrades require manual DB repair.

## See Also

- **gitea** — self-hosted Git service that pairs well with Nextcloud for code hosting alongside file storage
- **vaultwarden** — self-hosted password manager for securing credentials used across Nextcloud and other services

## References
See `references/` for:
- `docker-compose.yml.annotated` — annotated Docker Compose configuration
- `docs.md` — official documentation links
