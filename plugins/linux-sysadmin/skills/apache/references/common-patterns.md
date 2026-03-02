# Apache Common Patterns

Each block below is a complete, copy-paste-ready config. On Debian/Ubuntu, place
VirtualHost files in `/etc/apache2/sites-available/<name>.conf` and enable with
`sudo a2ensite <name>.conf && sudo systemctl reload apache2`. On RHEL/Fedora,
place them in `/etc/httpd/conf.d/<name>.conf` (no enable step needed).

---

## 1. Basic HTTP VirtualHost

Serves a static site from `/var/www/mysite`. No SSL. Suitable for internal tools
or as the HTTP side of a redirect-to-HTTPS setup.

```apache
<VirtualHost *:80>
    ServerName mysite.example.com
    ServerAlias www.mysite.example.com
    ServerAdmin webmaster@example.com
    DocumentRoot /var/www/mysite

    <Directory /var/www/mysite>
        # FollowSymLinks is required for mod_rewrite to work.
        # -Indexes prevents directory listings if no index file exists.
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    CustomLog /var/log/apache2/mysite-access.log combined
    ErrorLog  /var/log/apache2/mysite-error.log
</VirtualHost>
```

---

## 2. HTTPS VirtualHost with Let's Encrypt

Terminates TLS at Apache using certs placed by Certbot at
`/etc/letsencrypt/live/<domain>/`. Requires `mod_ssl` and `mod_headers`.

```apache
# HTTP vhost: redirect all traffic to HTTPS (see pattern 6 for details).
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com
    Redirect permanent / https://example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com
    ServerAdmin webmaster@example.com
    DocumentRoot /var/www/example.com

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    SSLProtocol      -all +TLSv1.2 +TLSv1.3
    SSLCipherSuite   ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
    SSLHonorCipherOrder Off

    # HSTS: 2 years, include subdomains. Only set in HTTPS vhosts.
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    <Directory /var/www/example.com>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    CustomLog /var/log/apache2/example.com-access.log combined
    ErrorLog  /var/log/apache2/example.com-error.log
</VirtualHost>
```

---

## 3. Reverse Proxy to a Local App

Proxies all traffic to a local app running on port 3000. Requires `mod_proxy`
and `mod_proxy_http`.

```apache
# Enable modules first (Debian):
#   sudo a2enmod proxy proxy_http headers && sudo systemctl reload apache2

<VirtualHost *:443>
    ServerName app.example.com
    ServerAdmin webmaster@example.com

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/app.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/app.example.com/privkey.pem
    SSLProtocol -all +TLSv1.2 +TLSv1.3

    # Disable forward proxy to prevent open proxy abuse.
    ProxyRequests Off

    # Tell upstream the original scheme so it can build correct redirect URLs.
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"

    # ProxyPass maps the URL path to the backend.
    # ProxyPassReverse rewrites Location headers in responses from the backend
    # so redirects point back at Apache, not the backend address.
    ProxyPass        / http://127.0.0.1:3000/
    ProxyPassReverse / http://127.0.0.1:3000/

    # Preserve the Host header so the upstream app sees the original hostname.
    ProxyPreserveHost On

    CustomLog /var/log/apache2/app-access.log combined
    ErrorLog  /var/log/apache2/app-error.log
</VirtualHost>
```

---

## 4. PHP-FPM via Unix Socket

Passes PHP requests to PHP-FPM through a Unix socket. Requires `mod_proxy` and
`mod_proxy_fcgi`. More efficient than TCP socket for local PHP-FPM; avoids
running PHP inside Apache (which requires prefork MPM).

```apache
# Enable modules (Debian):
#   sudo a2enmod proxy proxy_fcgi && sudo systemctl reload apache2
# Verify socket path: grep -r 'listen' /etc/php/8.2/fpm/pool.d/www.conf

<VirtualHost *:443>
    ServerName phpapp.example.com
    DocumentRoot /var/www/phpapp

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/phpapp.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/phpapp.example.com/privkey.pem
    SSLProtocol -all +TLSv1.2 +TLSv1.3

    <Directory /var/www/phpapp>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    # Route all .php file requests to PHP-FPM via FastCGI.
    # The pipe character after the socket path is required Apache syntax.
    # Replace php8.2 with the PHP version FPM is running.
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost"
    </FilesMatch>

    # Optional: deny direct access to sensitive PHP config files.
    <Files "wp-config.php">
        Require all denied
    </Files>

    CustomLog /var/log/apache2/phpapp-access.log combined
    ErrorLog  /var/log/apache2/phpapp-error.log
</VirtualHost>
```

---

## 5. Password-Protected Directory

Two approaches: per-directory `AuthConfig` in the VirtualHost block (preferred —
no .htaccess overhead), and a fallback `.htaccess` approach for when you can't
modify the VirtualHost config.

```apache
# --- Approach A: Directory block in VirtualHost (preferred) ---
# Create htpasswd file first:
#   htpasswd -c /etc/apache2/.htpasswd firstuser
#   htpasswd /etc/apache2/.htpasswd seconduser   (add more users)

<VirtualHost *:443>
    ServerName admin.example.com
    DocumentRoot /var/www/admin

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/admin.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/admin.example.com/privkey.pem

    <Directory /var/www/admin>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted

        # Basic authentication for this directory.
        AuthType Basic
        AuthName "Restricted Area"
        AuthUserFile /etc/apache2/.htpasswd
        Require valid-user
    </Directory>

    # Exempt a health-check path from authentication.
    <Location /health>
        Require all granted
    </Location>
</VirtualHost>

# --- Approach B: .htaccess (use only when VirtualHost config is unavailable) ---
# In the directory, create .htaccess with:
#
#   AuthType Basic
#   AuthName "Restricted Area"
#   AuthUserFile /etc/apache2/.htpasswd
#   Require valid-user
#
# The parent Directory block must have AllowOverride AuthConfig (or All).
```

---

## 6. Redirect HTTP to HTTPS

Two patterns. The `Redirect` directive is simpler; the `RewriteRule` approach
handles edge cases like preserving query strings when using older Apache versions.

```apache
# Pattern A: Redirect directive (simple and clear — preferred).
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com

    # 301 Permanent Redirect. Use 302 during testing to avoid browser caching.
    # "permanent" is an alias for 301.
    Redirect permanent / https://example.com/
</VirtualHost>

# Pattern B: mod_rewrite (more flexible — use when you need conditional logic).
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com

    RewriteEngine On
    # Exclude Let's Encrypt ACME challenge path from the redirect.
    RewriteCond %{REQUEST_URI} !^/.well-known/acme-challenge/
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
```

---

## 7. Static File Serving with Caching Headers

Configures aggressive browser caching for static assets using `mod_expires`.
Reduces repeat-visit bandwidth and improves load time.

```apache
# Enable modules (Debian):
#   sudo a2enmod expires headers && sudo systemctl reload apache2

<VirtualHost *:443>
    ServerName static.example.com
    DocumentRoot /var/www/static

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/static.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/static.example.com/privkey.pem

    <Directory /var/www/static>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted

        # Activate mod_expires for this directory.
        ExpiresActive On

        # Default: cache everything for 1 hour.
        ExpiresDefault "access plus 1 hour"

        # Cache long-lived static assets for 1 year.
        # Only safe when assets use content-hash filenames (e.g., app.a3f9b2.js).
        ExpiresByType image/jpeg         "access plus 1 year"
        ExpiresByType image/png          "access plus 1 year"
        ExpiresByType image/svg+xml      "access plus 1 year"
        ExpiresByType image/webp         "access plus 1 year"
        ExpiresByType text/css           "access plus 1 year"
        ExpiresByType application/javascript "access plus 1 year"
        ExpiresByType font/woff2         "access plus 1 year"
        ExpiresByType font/woff          "access plus 1 year"

        # HTML should not be cached long — it references the hashed assets.
        ExpiresByType text/html          "access plus 5 minutes"

        # Add immutable flag for truly long-cached assets (supported by modern browsers).
        # "immutable" tells the browser not to revalidate even on forced refresh.
        <FilesMatch "\.(css|js|woff2?|png|jpg|jpeg|webp|svg)$">
            Header append Cache-Control "public, immutable"
        </FilesMatch>
    </Directory>
</VirtualHost>
```

---

## 8. URL Rewrite Examples (mod_rewrite)

Common rewrite patterns. Requires `mod_rewrite` and `RewriteEngine On` in the
context where the rules apply. Rules are processed top-to-bottom; `[L]` stops
processing further rules on a match.

```apache
# Enable module (Debian):
#   sudo a2enmod rewrite && sudo systemctl reload apache2

<VirtualHost *:443>
    ServerName app.example.com
    DocumentRoot /var/www/app

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/app.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/app.example.com/privkey.pem

    <Directory /var/www/app>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted

        RewriteEngine On

        # --- SPA / front-controller routing ---
        # If the requested path is not a real file or directory, rewrite to index.php.
        # This is the standard pattern for Laravel, Symfony, WordPress, etc.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^ index.php [QSA,L]

        # --- Remove .php extension from URLs ---
        # Rewrite /page to /page.php if the .php file exists.
        RewriteCond %{REQUEST_FILENAME}.php -f
        RewriteRule ^([^.]+)$ $1.php [L]

        # --- Redirect old URL to new URL (permanent) ---
        RewriteRule ^/old-page/?$ /new-page [R=301,L]

        # --- Redirect based on condition (e.g., maintenance mode) ---
        # RewriteCond reads the next RewriteRule's conditions.
        # %{ENV:MAINTENANCE} can be set by a SetEnvIf or external script.
        # RewriteCond %{ENV:MAINTENANCE} =1
        # RewriteRule !^/maintenance.html$ /maintenance.html [R=302,L]
    </Directory>
</VirtualHost>
```

**RewriteRule flag reference:**

| Flag | Meaning |
|------|---------|
| `R=301` | External redirect, permanent |
| `R=302` | External redirect, temporary |
| `L` | Stop processing rules after this match |
| `QSA` | Append query string from original URL |
| `NC` | Case-insensitive pattern match |
| `NE` | Don't escape special characters in output |
| `PT` | Pass-through to next handler (use with Alias/ProxyPass) |

---

## 9. Rate Limiting

Apache has two main modules for rate limiting. `mod_ratelimit` limits bandwidth
per connection. `mod_evasive` detects and blocks rapid repeated requests (DoS
mitigation). For request-rate limiting similar to nginx's `limit_req`, `mod_evasive`
is the closest built-in option, though it is more of a DoS shield than a fine-grained
rate limiter.

```apache
# --- mod_ratelimit: limit download speed per connection ---
# Enable module (Debian): sudo a2enmod ratelimit && sudo systemctl reload apache2
# Limits bandwidth on the /downloads path to 400 KB/s per connection.
<Location /downloads>
    SetOutputFilter RATE_LIMIT
    SetEnv rate-limit 400
</Location>

# --- mod_evasive: block IPs that make too many requests too fast ---
# Install (Debian): sudo apt install libapache2-mod-evasive
# Install (RHEL):   sudo dnf install mod_evasive
# Enable (Debian):  sudo a2enmod evasive && sudo systemctl reload apache2

# Place this in apache2.conf or a conf-enabled/*.conf file.
<IfModule mod_evasive24.c>
    # Max requests to the same page within DOSPageInterval seconds.
    DOSPageCount        5
    DOSPageInterval     1

    # Max concurrent requests from the same IP within DOSSiteInterval seconds.
    DOSSiteCount        50
    DOSSiteInterval     1

    # How long to block an offending IP (seconds).
    DOSBlockingPeriod   10

    # Where to log blocked IPs.
    DOSLogDir           /var/log/apache2/mod_evasive

    # Optional: email alert on block event.
    # DOSEmailNotify    admin@example.com

    # Optional: whitelist trusted IPs.
    DOSWhitelist        127.0.0.1
</IfModule>
```

---

## 10. Custom Error Pages

Override Apache's default error pages with site-branded HTML.

```apache
<VirtualHost *:443>
    ServerName example.com
    DocumentRoot /var/www/example.com

    SSLEngine On
    SSLCertificateFile    /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    # Custom error page paths. The path is relative to DocumentRoot.
    # Alternatively, use an absolute filesystem path.
    ErrorDocument 400 /errors/400.html
    ErrorDocument 401 /errors/401.html
    ErrorDocument 403 /errors/403.html
    ErrorDocument 404 /errors/404.html
    ErrorDocument 500 /errors/500.html
    ErrorDocument 502 /errors/502.html
    ErrorDocument 503 /errors/503.html

    # Ensure the errors directory is accessible (it's inside DocumentRoot so
    # it inherits the Directory block's Require all granted).
    <Directory /var/www/example.com>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    # Optional: redirect errors to an external status page.
    # ErrorDocument 503 https://status.example.com

    CustomLog /var/log/apache2/example.com-access.log combined
    ErrorLog  /var/log/apache2/example.com-error.log
</VirtualHost>
```
