# Prometheus Documentation

## Official Prometheus Docs

- Getting started: https://prometheus.io/docs/prometheus/latest/getting_started/
- Configuration reference (`prometheus.yml`): https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- PromQL basics: https://prometheus.io/docs/prometheus/latest/querying/basics/
- PromQL functions reference: https://prometheus.io/docs/prometheus/latest/querying/functions/
- PromQL operators: https://prometheus.io/docs/prometheus/latest/querying/operators/
- Alerting rules: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
- Recording rules: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
- HTTP API: https://prometheus.io/docs/prometheus/latest/querying/api/
- Storage and retention: https://prometheus.io/docs/prometheus/latest/storage/
- remote_write configuration: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write

## Alertmanager Docs

- Overview: https://prometheus.io/docs/alerting/latest/overview/
- Configuration reference (`alertmanager.yml`): https://prometheus.io/docs/alerting/latest/configuration/
- Routing tree: https://prometheus.io/docs/alerting/latest/configuration/#route
- Notification templates: https://prometheus.io/docs/alerting/latest/notifications/
- `amtool` CLI reference: https://prometheus.io/docs/alerting/latest/management_api/

## Exporters

- Exporters and integrations catalog: https://prometheus.io/docs/instrumenting/exporters/
- node_exporter (host metrics): https://github.com/prometheus/node_exporter
- blackbox_exporter (HTTP/TCP/DNS probing): https://github.com/prometheus/blackbox_exporter
- mysqld_exporter: https://github.com/prometheus/mysqld_exporter
- postgres_exporter: https://github.com/prometheus-community/postgres_exporter
- redis_exporter: https://github.com/oliver006/redis_exporter
- nginx prometheus exporter: https://github.com/nginxinc/nginx-prometheus-exporter
- Writing exporters guide: https://prometheus.io/docs/instrumenting/writing_exporters/

## Community Resources

- awesome-prometheus: https://github.com/roaldnefs/awesome-prometheus
- Prometheus Operator (Kubernetes): https://github.com/prometheus-operator/prometheus-operator
- PromQL cheat sheet: https://promlabs.com/promql-cheat-sheet/
- PromLens (PromQL visual editor): https://promlens.com/
- Alerting runbook examples: https://github.com/prometheus-operator/runbooks

## Long-Term Storage

- Thanos (multi-cluster, object storage): https://thanos.io/
- Grafana Mimir (horizontally scalable): https://grafana.com/docs/mimir/latest/
- VictoriaMetrics (single-binary, high compression): https://docs.victoriametrics.com/

## Man Pages

- `man prometheus` (if installed from package)
- `prometheus --help` — full list of command-line flags
- `promtool --help` — config/rule validation and TSDB tooling
- `amtool --help` — Alertmanager CLI
