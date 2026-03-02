# iotop Documentation

## Man Pages

- `man iotop` — iotop simple top-like I/O monitor
- `man 7 capabilities` — Linux capability system (relevant for CAP_SYS_ADMIN requirement)

## Upstream Projects

- iotop-c (C rewrite, actively maintained): https://github.com/Tomas-M/iotop
- Original Python iotop (abandoned): http://guichaz.free.fr/iotop/
- iotop-c package tracker (Debian): https://packages.debian.org/search?keywords=iotop-c
- iotop-c package tracker (Fedora): https://packages.fedoraproject.org/pkgs/iotop-c/

## Kernel Interfaces

- taskstats interface (used by iotop): https://docs.kernel.org/accounting/taskstats.html
- I/O accounting overview: https://docs.kernel.org/accounting/delay-accounting.html
- CONFIG_TASK_IO_ACCOUNTING kernel option: https://cateee.net/lkddb/web-lkddb/TASK_IO_ACCOUNTING.html

## Community Resources

- ArchWiki — iotop: https://wiki.archlinux.org/title/Iotop
- Linux I/O performance analysis (Brendan Gregg): https://www.brendangregg.com/linuxperf.html
- USE Method for storage: https://www.brendangregg.com/USEmethod/use-linux.html
