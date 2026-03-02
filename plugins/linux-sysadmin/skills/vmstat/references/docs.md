# vmstat Documentation

## Man Pages

- `man vmstat` — report virtual memory statistics
- `man proc` — `/proc` filesystem entries that vmstat reads (meminfo, stat, diskstats)
- `man free` — companion tool for memory-only summary

## Official / Upstream

- procps-ng project (home of vmstat): https://gitlab.com/procps-ng/procps
- procps-ng releases: https://gitlab.com/procps-ng/procps/-/releases

## Kernel Interfaces

- `/proc/meminfo` reference: https://docs.kernel.org/filesystems/proc.html#meminfo
- `/proc/vmstat` counters: https://docs.kernel.org/filesystems/proc.html#vmstat
- `/proc/diskstats` format: https://www.kernel.org/doc/Documentation/ABI/testing/procfs-diskstats
- Kernel swap documentation: https://docs.kernel.org/mm/page_reclaim.html

## Community Resources

- ArchWiki — procps: https://wiki.archlinux.org/title/procps
- Brendan Gregg — Linux performance tools (vmstat section): https://www.brendangregg.com/linuxperf.html
- USE Method — memory and CPU saturation: https://www.brendangregg.com/USEmethod/use-linux.html
- Red Hat — Understanding vmstat output: https://access.redhat.com/solutions/1353
