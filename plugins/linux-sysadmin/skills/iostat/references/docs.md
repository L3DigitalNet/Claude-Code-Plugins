# iostat Documentation

## Man Pages

- `man iostat` — report CPU statistics and I/O statistics for block devices and partitions
- `man sadc` — sysstat system activity data collector (iostat data source)
- `man sysstat` — sysstat package overview

## Official / Upstream

- sysstat project (home of iostat): https://github.com/sysstat/sysstat
- sysstat documentation: https://sysstat.github.io/
- sysstat releases: https://github.com/sysstat/sysstat/releases
- iostat man page (online, latest): https://sysstat.github.io/sysstat-man-pages/iostat.1.html

## Kernel Interfaces

- `/proc/diskstats` format (raw data source): https://www.kernel.org/doc/Documentation/ABI/testing/procfs-diskstats
- Block layer statistics overview: https://docs.kernel.org/block/stat.html
- NVMe namespaces and device naming: https://docs.kernel.org/admin-guide/nvme.html

## Community Resources

- ArchWiki — sysstat: https://wiki.archlinux.org/title/Sysstat
- Brendan Gregg — disk performance analysis: https://www.brendangregg.com/disks.html
- Brendan Gregg — iostat disk utilization: https://www.brendangregg.com/blog/2017-08-26/linux-iostat-utilization.html
- USE Method — disk saturation and utilization: https://www.brendangregg.com/USEmethod/use-linux.html
- Red Hat — Understanding iostat output: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/monitoring_and_managing_system_status_and_performance/monitoring-storage-devices-with-iostat_monitoring-and-managing-system-status-and-performance
