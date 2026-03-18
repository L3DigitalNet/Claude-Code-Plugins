---
name: elk-stack
description: >
  Elastic Stack (ELK) log aggregation and analytics — Elasticsearch cluster management,
  Kibana dashboards, Logstash pipelines, Filebeat/Metricbeat agents, index lifecycle
  management, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting the ELK stack (Elasticsearch, Logstash, Kibana).
triggerPhrases:
  - "elasticsearch"
  - "kibana"
  - "logstash"
  - "ELK"
  - "elastic stack"
  - "filebeat"
  - "metricbeat"
  - "log aggregation elastic"
  - "elasticsearch cluster"
  - "elasticsearch index"
  - "kibana dashboard"
  - "logstash pipeline"
  - "ILM"
  - "index lifecycle"
globs:
  - "**/elasticsearch.yml"
  - "**/kibana.yml"
  - "**/logstash.conf"
  - "**/logstash.yml"
  - "**/filebeat.yml"
  - "**/metricbeat.yml"
last_verified: "2026-03"
---

## Identity

- **Components**: Elasticsearch (search/analytics engine), Kibana (visualization/dashboards), Logstash (pipeline processor), Beats (lightweight shippers: Filebeat, Metricbeat, Packetbeat, etc.)
- **License**: Triple-licensed since 8.16 — AGPL v3, SSPL, and Elastic License v2. Client libraries remain Apache 2.0.
- **Elasticsearch config**: `/etc/elasticsearch/elasticsearch.yml`
- **Elasticsearch data**: `/var/lib/elasticsearch`
- **Elasticsearch logs**: `/var/log/elasticsearch/`
- **Elasticsearch JVM options**: `/etc/elasticsearch/jvm.options`, `/etc/elasticsearch/jvm.options.d/`
- **Elasticsearch certs** (auto-generated on first start in 8.x): `/etc/elasticsearch/certs/`
- **Elasticsearch unit**: `elasticsearch.service`
- **Kibana config**: `/etc/kibana/kibana.yml`
- **Kibana data**: `/var/lib/kibana`
- **Kibana unit**: `kibana.service`
- **Logstash config**: `/etc/logstash/logstash.yml`
- **Logstash pipelines**: `/etc/logstash/conf.d/*.conf` (single pipeline) or `/etc/logstash/pipelines.yml` (multi-pipeline)
- **Logstash data**: `/var/lib/logstash`
- **Logstash unit**: `logstash.service`
- **Filebeat config**: `/etc/filebeat/filebeat.yml`
- **Metricbeat config**: `/etc/metricbeat/metricbeat.yml`
- **Default ports**: ES HTTP 9200, ES transport 9300, Kibana 5601, Logstash Beats input 5044, Logstash monitoring API 9600
- **Install methods**: APT/YUM repo (artifacts.elastic.co), Docker images (docker.elastic.co), tar/zip archives, Helm charts
- **Version rule**: All stack components must run the same major.minor version

## Quick Start

### APT install (Debian/Ubuntu) — Elasticsearch + Kibana

```bash
# 1. Import the Elastic GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
  | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# 2. Add the 8.x APT repository
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# 3. Install Elasticsearch and Kibana
sudo apt-get update && sudo apt-get install elasticsearch kibana

# 4. Start Elasticsearch (security auto-configures on first boot)
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch

# First-start output prints:
#   - Password for the "elastic" superuser
#   - Kibana enrollment token (valid 30 minutes)
#   - Node enrollment token for adding ES nodes
# Save these. To reset the elastic password later:
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic

# 5. Verify ES is running (uses HTTPS by default in 8.x)
curl -k -u elastic:<password> https://localhost:9200

# 6. Enroll and start Kibana
sudo /usr/share/kibana/bin/kibana-setup --enrollment-token <token>
sudo systemctl enable --now kibana

# 7. Access Kibana at http://localhost:5601
#    Log in with elastic / <password>
```

Do NOT use `add-apt-repository` — Elastic does not provide a source package, and the extra `deb-src` entry causes errors.

### Docker (single-node dev)

```bash
docker network create elastic

docker run -d --name es01 --net elastic \
  -p 9200:9200 -m 1GB \
  -e "discovery.type=single-node" \
  docker.elastic.co/elasticsearch/elasticsearch:8.17.0

# Grab the generated password and enrollment token from the logs:
docker logs es01 2>&1 | grep -E "Password|enrollment token"

docker run -d --name kib01 --net elastic \
  -p 5601:5601 \
  docker.elastic.co/kibana/kibana:8.17.0

# Open http://localhost:5601 and paste the enrollment token
```

## Key Operations

| Task | Command |
|------|---------|
| Cluster health | `curl -k -u elastic:$PASS https://localhost:9200/_cluster/health?pretty` |
| List indices | `curl -k -u elastic:$PASS 'https://localhost:9200/_cat/indices?v&s=index'` |
| List shards | `curl -k -u elastic:$PASS 'https://localhost:9200/_cat/shards?v'` |
| Index stats | `curl -k -u elastic:$PASS 'https://localhost:9200/<index>/_stats?pretty'` |
| Create index | `curl -k -u elastic:$PASS -X PUT 'https://localhost:9200/my-index' -H 'Content-Type: application/json' -d '{"settings":{"number_of_shards":1,"number_of_replicas":0}}'` |
| Delete index | `curl -k -u elastic:$PASS -X DELETE 'https://localhost:9200/my-index'` |
| Simple search | `curl -k -u elastic:$PASS 'https://localhost:9200/my-index/_search?q=error&pretty'` |
| Query DSL search | `curl -k -u elastic:$PASS -X POST 'https://localhost:9200/my-index/_search' -H 'Content-Type: application/json' -d '{"query":{"match":{"message":"error"}}}'` |
| Node stats | `curl -k -u elastic:$PASS 'https://localhost:9200/_nodes/stats?pretty'` |
| Allocation explanation | `curl -k -u elastic:$PASS 'https://localhost:9200/_cluster/allocation/explain?pretty'` |
| Kibana status | `curl http://localhost:5601/api/status` |
| Logstash pipeline test | `/usr/share/logstash/bin/logstash --config.test_and_exit -f /etc/logstash/conf.d/` |
| Logstash node stats | `curl http://localhost:9600/_node/stats?pretty` |
| Logstash hot threads | `curl http://localhost:9600/_node/hot_threads?human` |
| Reset elastic password | `sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic` |
| Generate enrollment token | `sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana` |
| Generate node token | `sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node` |

## Expected Ports

- **9200/tcp** — Elasticsearch HTTP API (client requests, REST API)
- **9300/tcp** — Elasticsearch transport (inter-node cluster communication)
- **5601/tcp** — Kibana web UI
- **5044/tcp** — Logstash Beats input (Filebeat/Metricbeat ship here)
- **9600/tcp** — Logstash monitoring API
- Verify: `ss -tlnp | grep -E '9200|9300|5601|5044|9600'`
- Firewall: ES and Kibana should not be exposed publicly without authentication and TLS. Elasticsearch 8.x enables TLS and auth by default; Kibana should sit behind a reverse proxy for production.

## Health Checks

1. `systemctl is-active elasticsearch` → `active`
2. `curl -k -u elastic:$PASS https://localhost:9200/_cluster/health?pretty` → `"status" : "green"` (or `"yellow"` on single-node since replicas cannot be allocated)
3. `curl -k -u elastic:$PASS https://localhost:9200` → returns cluster name, version, tagline
4. `curl http://localhost:5601/api/status` → Kibana overall status `"available"`
5. `systemctl is-active logstash` → `active`
6. `curl http://localhost:9600/_node/stats?pretty` → Logstash pipeline stats with `events.in` / `events.out`

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Cluster health **yellow** | Replica shards unassigned; typical on single-node clusters because replicas need a second node | Set `number_of_replicas: 0` on affected indices: `PUT /index/_settings {"index":{"number_of_replicas":0}}` — or add a second node |
| Cluster health **red** | One or more primary shards unassigned (data unavailable) | `GET /_cluster/allocation/explain` to find root cause; recover the failed node, restore from snapshot, or as last resort `POST /_cluster/reroute` with `allocate_empty_primary` (data loss) |
| Elasticsearch OOM killed | JVM heap too large or too small | Set `-Xms` and `-Xmx` to the same value, at most 50% of RAM and no more than ~31 GB (compressed oops threshold). Edit `/etc/elasticsearch/jvm.options.d/heap.options`. Since 7.11, ES auto-sizes heap by default. |
| Disk watermark exceeded (low 85%) | Disk >85% full; ES stops allocating new shards | Free disk space, delete old indices, or raise the watermark: `PUT /_cluster/settings {"persistent":{"cluster.routing.allocation.disk.watermark.low":"90%"}}` |
| Disk flood stage (95%) | Disk >95% full; indices set to read-only-allow-delete | Free space, then remove the block: `PUT /*/_settings {"index.blocks.read_only_allow_delete":null}` |
| Split brain (pre-7.x concern) | Nodes form separate clusters electing different masters | In ES 7+/8+, quorum-based voting replaces `minimum_master_nodes`. Use `discovery.seed_hosts` and `cluster.initial_master_nodes` correctly. Ensure an odd number of master-eligible nodes (3 minimum for HA). |
| Logstash pipeline errors | Grok parse failure, codec mismatch, or output unreachable | Test config: `logstash --config.test_and_exit -f /etc/logstash/conf.d/`. Check `_grokparsefailure` tag in output. Use `stdout { codec => rubydebug }` to debug. |
| Logstash backpressure / slow | Pipeline workers insufficient or output bottleneck | Increase `pipeline.workers` in `logstash.yml` (default: number of CPU cores). Check ES indexing rate and bulk queue. |
| Kibana "Unable to connect to Elasticsearch" | Wrong URL, expired enrollment token, or TLS mismatch | Verify `elasticsearch.hosts` in `kibana.yml`. Re-enroll if needed: `kibana-setup --enrollment-token <token>`. Check that Kibana trusts the ES CA cert. |
| Mapping explosion (>1000 fields) | Dynamic mapping indexes arbitrary JSON keys as fields | Set `index.mapping.total_fields.limit` or disable dynamic mapping: `"dynamic": "strict"` in index template. Restructure data to avoid unbounded field creation. |
| Certificate errors after upgrade | Auto-generated certs from initial setup may not cover new node names | Regenerate certs with `elasticsearch-certutil` or use the enrollment token workflow for new nodes. |

## Pain Points

- **JVM heap sizing**: ES defaults to auto-sizing since 7.11, which works for most cases. Manual override: set `-Xms` equal to `-Xmx`, at most 50% of available RAM, capped at ~31 GB to stay within compressed ordinary object pointers (compressed oops). The other 50% is used by the OS filesystem cache, which ES relies on heavily for segment reads.
- **Shard strategy**: Target 10-50 GB per shard. Keep shards per node below 20 per GB of heap (e.g., a 30 GB heap node should have fewer than 600 shards). Max 1000 non-frozen shards per node by default. For time-series data, use data streams with ILM rollover on `max_primary_shard_size: 50gb`.
- **Mapping explosions**: Default field limit is 1000 per index. Dynamic mapping on arbitrary JSON creates fields for every unique key. Prevention: use `"dynamic": "strict"` or `"dynamic": "runtime"` in index mappings. Raising the limit is a band-aid, not a fix.
- **Security is on by default in 8.x**: First start generates TLS certs, the `elastic` superuser password, and enrollment tokens. All HTTP calls require HTTPS and auth. This catches people upgrading from 7.x where security was opt-in. To connect curl: `curl -k -u elastic:<pass> https://...` (use `-k` to skip cert verification during dev, or pass `--cacert /etc/elasticsearch/certs/http_ca.crt`).
- **License tiers**: The free "Basic" tier includes core search, Kibana, ILM, snapshot/restore, and basic security (native realm auth, TLS). Paid tiers (Gold, Platinum, Enterprise) add LDAP/SAML/OIDC auth, machine learning, cross-cluster replication, and advanced monitoring. AGPL covers the source code license; the feature tier is separate.
- **Version compatibility**: Every component in the stack (ES, Kibana, Logstash, Beats) must run the same major.minor version. Beats can be one minor version ahead or behind ES, but Kibana must match exactly. Upgrade order: Elasticsearch first, then Kibana, then Logstash/Beats.
- **ILM phases**: Hot (actively written/queried) -> Warm (infrequent updates) -> Cold (rare queries, slower storage OK) -> Frozen (searchable snapshots, minimal resources) -> Delete. Each phase has actions: rollover, shrink, force merge, searchable snapshot, delete. Attach ILM policies via index templates; data streams handle rollover automatically.

## See Also

- `loki` — Grafana Loki log aggregation (label-indexed, lower resource overhead)
- `prometheus` — Metrics collection and alerting (complements ELK for time-series metrics)
- `grafana` — Visualization platform (alternative to Kibana, works with ES as a data source too)
- `journald` — systemd journal (local log source, often shipped to ES via Filebeat)

## References

See `references/` for:
- `docs.md` — verified official documentation links (elastic.co/guide)
- `common-patterns.md` — Docker Compose stack, Filebeat direct to ES, Filebeat through Logstash, index templates, ILM policies, basic security setup, common KQL queries
