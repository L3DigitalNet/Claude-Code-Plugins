# cron Documentation

## Man Pages
- `man 1 crontab` — user crontab command (list, edit, remove)
- `man 5 crontab` — crontab file format (fields, special characters, environment)
- `man 8 cron` — daemon behavior, logging, security
- `man 8 crond` — RHEL/Fedora variant
- `man 1 at` — one-shot job scheduling (alternative to cron for non-recurring tasks)
- `man 8 run-parts` — how drop-in directories are executed (filename restrictions)

## Expression Reference
- Crontab expression calculator (interactive): https://crontab.guru/
  The single most useful tool when writing or debugging cron schedules. Enter an
  expression and it shows the next N run times in plain English.
- Common expression examples: https://crontab.guru/examples.html

## Official / Distro Documentation
- Vixie cron (Debian/Ubuntu default): https://manpages.debian.org/stable/cron/cron.8.en.html
- cronie (RHEL/Fedora default): https://github.com/cronie-crond/cronie
- Ubuntu cron help: https://help.ubuntu.com/community/CronHowto

## systemd Timer Alternative
For new services on systemd-based systems, systemd timers are the recommended
alternative. They integrate with journald (no mail), support calendar expressions,
and expose run history via `systemctl list-timers`.

- systemd timer units: https://www.freedesktop.org/software/systemd/man/systemd.timer.html
- Calendar expression syntax: https://www.freedesktop.org/software/systemd/man/systemd.time.html
- Comparison (cron vs systemd timers): https://wiki.archlinux.org/title/Systemd/Timers

Key difference: systemd timers require two unit files (a `.timer` and a `.service`),
but gain dependency tracking, catch-up on missed runs (`Persistent=true`), and
structured logging — all things cron cannot do natively.

## `at` Command (One-Shot Scheduling)
For jobs that should run once at a specific future time, `at` is simpler than cron.
- `echo "/usr/local/bin/job.sh" | at 03:00` — run at 3 AM tonight
- `at -l` — list pending jobs
- `atrm <job-id>` — remove a pending job
- Requires `atd` daemon: `apt install at` / `dnf install at`
