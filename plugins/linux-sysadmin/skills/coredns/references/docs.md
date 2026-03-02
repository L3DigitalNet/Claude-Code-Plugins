# CoreDNS Documentation

## Official

- Project site: https://coredns.io/
- Manual (all versions): https://coredns.io/manual/toc/
- Corefile format reference: https://coredns.io/2017/07/23/corefile-explained/
- Plugin index: https://coredns.io/plugins/
- GitHub repository: https://github.com/coredns/coredns
- Releases (binary downloads): https://github.com/coredns/coredns/releases

## Plugin Documentation

- `cache`: https://coredns.io/plugins/cache/
- `forward`: https://coredns.io/plugins/forward/
- `kubernetes`: https://coredns.io/plugins/kubernetes/
- `rewrite`: https://coredns.io/plugins/rewrite/
- `hosts`: https://coredns.io/plugins/hosts/
- `file` (authoritative zones): https://coredns.io/plugins/file/
- `prometheus` (metrics): https://coredns.io/plugins/metrics/
- `health`: https://coredns.io/plugins/health/
- `ready`: https://coredns.io/plugins/ready/
- `log`: https://coredns.io/plugins/log/
- `errors`: https://coredns.io/plugins/errors/
- `loop`: https://coredns.io/plugins/loop/
- `loadbalance`: https://coredns.io/plugins/loadbalance/
- `transfer` (zone transfers): https://coredns.io/plugins/transfer/
- `auto` (auto-loaded zone files): https://coredns.io/plugins/auto/
- `etcd` (etcd-backed records): https://coredns.io/plugins/etcd/
- External/community plugins: https://coredns.io/explugins/

## Kubernetes Integration

- CoreDNS in Kubernetes: https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
- Customizing DNS service (stub zones, upstream overrides): https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#coredns-configmap-options
- DNS for services and pods: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Debugging DNS resolution in k8s: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
- CoreDNS migration from kube-dns: https://coredns.io/2018/05/21/migration-from-kube-dns-to-coredns/

## Deployment Guides

- Deploying CoreDNS as a service (systemd): https://coredns.io/2017/07/26/how-to-deploy-and-configure-the-coreDNS-server/
- Docker deployment: https://hub.docker.com/r/coredns/coredns
- Building with custom plugins (`xcorefile`): https://github.com/coredns/xcorefile
- Plugin development guide: https://coredns.io/2016/12/19/writing-plugins-for-coredns/

## Observability

- Metrics reference (all exposed metrics): https://coredns.io/plugins/metrics/#exposed-metrics
- Grafana dashboard for CoreDNS: https://grafana.com/grafana/dashboards/5926

## Man pages

- `man coredns` (if installed via package manager)
