# Loki Documentation

## Official Grafana Loki Docs
- Main docs: https://grafana.com/docs/loki/latest/
- Architecture overview: https://grafana.com/docs/loki/latest/get-started/architecture/
- Components (ingester, querier, ruler, compactor): https://grafana.com/docs/loki/latest/get-started/components/

## Configuration Reference
- Loki configuration: https://grafana.com/docs/loki/latest/configuration/
- Promtail configuration: https://grafana.com/docs/loki/latest/clients/promtail/configuration/
- Schema config and migration: https://grafana.com/docs/loki/latest/operations/storage/schema/

## LogQL
- LogQL reference: https://grafana.com/docs/loki/latest/query/
- Log queries (stream selectors, filters, parsers): https://grafana.com/docs/loki/latest/query/log_queries/
- Metric queries (rate, count_over_time, unwrap): https://grafana.com/docs/loki/latest/query/metric_queries/
- Template functions: https://grafana.com/docs/loki/latest/query/template_functions/

## Storage Backends
- Storage overview: https://grafana.com/docs/loki/latest/operations/storage/
- TSDB (recommended for Loki 2.8+): https://grafana.com/docs/loki/latest/operations/storage/tsdb/
- BoltDB Shipper (older local storage): https://grafana.com/docs/loki/latest/operations/storage/boltdb-shipper/

## Promtail
- Pipeline stages reference: https://grafana.com/docs/loki/latest/clients/promtail/stages/
- Scrape configurations: https://grafana.com/docs/loki/latest/clients/promtail/scraping/
- Docker service discovery: https://grafana.com/docs/loki/latest/clients/promtail/configuration/#docker_sd_config
- Kubernetes service discovery: https://grafana.com/docs/loki/latest/clients/promtail/configuration/#kubernetes_sd_config

## logcli
- logcli usage and reference: https://grafana.com/docs/loki/latest/query/logcli/

## Operations and Best Practices
- Label best practices (the most important page for avoiding cardinality issues): https://grafana.com/docs/loki/latest/get-started/labels/best-practices/
- Retention and compaction: https://grafana.com/docs/loki/latest/operations/storage/retention/
- Recording rules and alerting: https://grafana.com/docs/loki/latest/alert/
- Ruler configuration: https://grafana.com/docs/loki/latest/configuration/#ruler

## Deployment
- Docker Compose quickstart: https://grafana.com/docs/loki/latest/setup/install/docker/
- Helm chart (loki-stack): https://grafana.com/docs/loki/latest/setup/install/helm/
- Binary install: https://grafana.com/docs/loki/latest/setup/install/local/

## GitHub Releases
- Loki releases (binaries): https://github.com/grafana/loki/releases
