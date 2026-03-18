---
name: kafka
description: >
  Apache Kafka event streaming platform administration: KRaft-mode cluster setup,
  broker configuration, topic and partition management, producer/consumer CLI tools,
  consumer groups, replication, JMX monitoring, log retention, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting kafka.
triggerPhrases:
  - "kafka"
  - "kafka broker"
  - "kafka topic"
  - "kafka producer"
  - "kafka consumer"
  - "kafka consumer group"
  - "kafka cluster"
  - "KRaft"
  - "kafka partitions"
  - "kafka replication"
  - "event streaming"
  - "kafka-topics"
  - "kafka-console-producer"
  - "kafka-console-consumer"
  - "kafka-consumer-groups"
globs:
  - "**/server.properties"
  - "**/kraft/**/*.properties"
  - "**/kafka/**/*.properties"
last_verified: "2026-03"
---

## Identity

- **Runtime**: JVM (Java 17+ required)
- **License**: Apache License 2.0
- **Current version**: 4.2.0 (February 2026); ZooKeeper support removed in 4.0
- **Metadata mode**: KRaft only (Kafka Raft consensus, built-in; no external dependency)
- **Config (combined)**: `/opt/kafka/config/server.properties`
- **Config (separate controller)**: `/opt/kafka/config/kraft/controller.properties`
- **Config (separate broker)**: `/opt/kafka/config/kraft/broker.properties`
- **Data dir**: `/opt/kafka/data` (set via `log.dirs`)
- **Logs**: `journalctl -u kafka` (systemd), or stdout when started via `kafka-server-start.sh`
- **Unit**: `kafka.service` (user-created; Kafka ships as a tarball, not a distro package)
- **Install**: Download tarball from https://kafka.apache.org/community/downloads/, extract to `/opt/kafka`
- **Docker image**: `apache/kafka:4.2.0` (official JVM image); `apache/kafka-native` (GraalVM, experimental, dev only)

## Quick Start

### Bare-metal (tarball + systemd)

```bash
# 1. Install Java 17+
sudo apt install openjdk-21-jre-headless    # Debian/Ubuntu
sudo dnf install java-21-openjdk-headless   # RHEL/Fedora

# 2. Create a dedicated user
sudo useradd -r -m -U -d /opt/kafka -s /bin/false kafka

# 3. Download and extract Kafka
cd /opt
sudo wget https://downloads.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz
sudo tar -xzf kafka_2.13-4.2.0.tgz
sudo mv kafka_2.13-4.2.0 kafka
sudo chown -R kafka:kafka /opt/kafka

# 4. Generate a cluster ID and format storage (KRaft)
KAFKA_CLUSTER_ID="$(/opt/kafka/bin/kafka-storage.sh random-uuid)"
sudo -u kafka /opt/kafka/bin/kafka-storage.sh format \
  --standalone -t "$KAFKA_CLUSTER_ID" -c /opt/kafka/config/server.properties

# 5. Create a systemd unit (/etc/systemd/system/kafka.service)
cat <<'EOF' | sudo tee /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka Server
After=network.target

[Service]
Type=simple
User=kafka
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF

# 6. Start Kafka
sudo systemctl daemon-reload
sudo systemctl enable --now kafka

# 7. Verify
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
```

### Docker (single-node dev)

```bash
docker run -d --name kafka \
  -p 9092:9092 \
  apache/kafka:4.2.0
```

The official image runs in KRaft combined mode with no extra configuration needed for local development.

## Key Operations

| Task | Command |
|------|---------|
| Start broker | `sudo systemctl start kafka` |
| Stop broker | `sudo systemctl stop kafka` |
| Service status | `systemctl status kafka` |
| Create topic | `kafka-topics.sh --create --topic my-topic --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092` |
| List topics | `kafka-topics.sh --list --bootstrap-server localhost:9092` |
| Describe topic | `kafka-topics.sh --describe --topic my-topic --bootstrap-server localhost:9092` |
| Delete topic | `kafka-topics.sh --delete --topic my-topic --bootstrap-server localhost:9092` |
| Alter partitions | `kafka-topics.sh --alter --topic my-topic --partitions 6 --bootstrap-server localhost:9092` |
| Produce messages | `kafka-console-producer.sh --topic my-topic --bootstrap-server localhost:9092` |
| Consume from beginning | `kafka-console-consumer.sh --topic my-topic --from-beginning --bootstrap-server localhost:9092` |
| Consume with group | `kafka-console-consumer.sh --topic my-topic --group my-group --bootstrap-server localhost:9092` |
| List consumer groups | `kafka-consumer-groups.sh --list --bootstrap-server localhost:9092` |
| Describe consumer group | `kafka-consumer-groups.sh --describe --group my-group --bootstrap-server localhost:9092` |
| Reset offsets (dry run) | `kafka-consumer-groups.sh --group my-group --topic my-topic --reset-offsets --to-earliest --dry-run --bootstrap-server localhost:9092` |
| Reset offsets (execute) | `kafka-consumer-groups.sh --group my-group --topic my-topic --reset-offsets --to-earliest --execute --bootstrap-server localhost:9092` |
| Delete consumer group | `kafka-consumer-groups.sh --delete --group my-group --bootstrap-server localhost:9092` |
| Cluster metadata | `kafka-metadata.sh --snapshot /opt/kafka/data/__cluster_metadata-0/00000000000000000000.log --cluster-id <id>` |
| Check KRaft quorum | `kafka-features.sh --bootstrap-controller localhost:9093 describe` |
| Generate cluster ID | `kafka-storage.sh random-uuid` |
| Format storage | `kafka-storage.sh format --standalone -t <cluster-id> -c config/server.properties` |

All CLI tools are in `/opt/kafka/bin/`. Omit the `.sh` suffix on the Docker image (it uses wrapper scripts without the extension).

## Expected Ports

- **9092/tcp** -- broker client listener (producer/consumer connections)
- **9093/tcp** -- controller listener (KRaft inter-controller and broker-to-controller RPCs)
- Verify: `ss -tlnp | grep -E '9092|9093'`
- Firewall: expose 9092 only to authorized clients. Port 9093 is internal to the cluster; block from external access. In production, use SASL_SSL or mTLS on both listeners.

## Health Checks

1. `systemctl is-active kafka` -> `active`
2. `kafka-topics.sh --list --bootstrap-server localhost:9092` -> returns topic list without error
3. `kafka-broker-api-versions.sh --bootstrap-server localhost:9092` -> shows API versions (confirms broker is responding)
4. JMX: `UnderReplicatedPartitions == 0`, `OfflinePartitionsCount == 0`, `ActiveControllerCount == 1` (exactly one broker reports 1)
5. Consumer lag: `kafka-consumer-groups.sh --describe --group <group> --bootstrap-server localhost:9092` -> LAG column near 0 for healthy consumers

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Cluster ID doesn't match stored` on startup | Formatted storage with a different cluster ID than metadata on disk | Delete data in `log.dirs` and re-run `kafka-storage.sh format` with the correct cluster ID |
| `java.net.BindException: Address already in use` | Port 9092 or 9093 already occupied | `ss -tlnp \| grep 9092` to find the conflicting process; stop it or change `listeners` in server.properties |
| `LEADER_NOT_AVAILABLE` on produce/consume | Topic just created; leader election in progress, or broker hosting the leader is down | Wait a few seconds for election to complete; if persistent, check broker logs and `kafka-topics.sh --describe` for partition state |
| `NotEnoughReplicasException` | `min.insync.replicas` exceeds available in-sync replicas for the partition | Bring down replicas back online; or temporarily lower `min.insync.replicas` (reduces durability guarantee) |
| Consumer group stuck in `PreparingRebalance` | Consumer repeatedly crashing or exceeding `session.timeout.ms` | Check consumer application logs; increase `session.timeout.ms` and `max.poll.interval.ms` if processing is slow |
| High consumer lag growing continuously | Consumer throughput lower than producer throughput | Add more consumers to the group (up to partition count); increase `fetch.min.bytes` and `max.poll.records` for batching |
| `RecordTooLargeException` | Message exceeds `message.max.bytes` (broker) or `max.request.size` (producer) | Increase both `message.max.bytes` on the broker/topic and `max.request.size` on the producer; also check `max.message.bytes` topic-level override |
| Disk full, broker becomes unresponsive | Log retention not configured or data volume exceeds expectations | Set `log.retention.hours` and `log.retention.bytes`; delete old topics; add disk capacity |
| `UNKNOWN_SERVER_ERROR` after upgrade | Incompatible inter-broker protocol or metadata version | Check `inter.broker.protocol.version` and `log.message.format.version` compatibility; follow rolling upgrade procedure |
| JMX shows `UnderReplicatedPartitions > 0` | Follower replica falling behind due to slow disk, network, or GC pauses | Check disk I/O with `iostat`, GC logs, network latency between brokers; restart lagging broker if needed |

## Pain Points

- **KRaft is now mandatory.** Kafka 4.0 removed ZooKeeper support entirely. Clusters on ZooKeeper must migrate using Kafka 3.9 (the last bridge release) before upgrading to 4.x. New clusters use KRaft from the start.
- **Combined mode is for dev only.** Running `process.roles=broker,controller` on a single node works for development, but production clusters should separate controller and broker roles so each can be scaled and rolled independently.
- **Partition count cannot be decreased.** You can increase partitions with `--alter`, but reducing them requires creating a new topic and migrating data. Plan partition counts based on peak consumer parallelism (one consumer per partition per group).
- **`auto.create.topics.enable` defaults to true.** A typo in a producer's topic name silently creates a garbage topic. Disable this in production and create topics explicitly.
- **`min.insync.replicas` defaults to 1.** With `acks=all` and a single ISR member, you get no durability benefit over `acks=1`. Set `min.insync.replicas=2` with `replication.factor=3` for production data safety.
- **Consumer group rebalancing can cause pauses.** The new consumer group protocol (KIP-848, GA in Kafka 4.0) with server-side assignment dramatically improves rebalance speed, but legacy `group.protocol=classic` consumers still experience stop-the-world rebalances. Use `group.protocol=consumer` for new applications.
- **JMX is disabled by default.** Set `JMX_PORT=9999` in the environment before starting the broker. In production, also set `KAFKA_JMX_OPTS` to enable authentication, since JMX without auth gives full access to the JVM.
- **Log retention is time-based by default (168 hours / 7 days).** Size-based retention (`log.retention.bytes`) defaults to -1 (unlimited). For high-throughput topics, set both time and size limits to prevent disk exhaustion.
- **`log.dirs` is not `log.dir`.** Both properties exist; `log.dirs` (plural) takes precedence and accepts a comma-separated list for striping across disks. Mixing them up causes data to land in an unexpected directory.

## See Also

- **rabbitmq** -- AMQP message broker (traditional message queuing with routing, exchanges, and per-message acknowledgment)
- **mosquitto** -- MQTT broker for IoT (lightweight pub/sub, different protocol and use case than Kafka's event streaming)
- **elk-stack** -- Log aggregation with Elasticsearch (Kafka often serves as a buffer between log shippers and Elasticsearch)
- **redis** -- In-memory store with pub/sub and streams (Redis Streams offer lightweight event streaming for smaller scale)

## References

See `references/` for:
- `docs.md` -- verified official documentation links (kafka.apache.org)
- `common-patterns.md` -- KRaft cluster setup, Docker Compose multi-broker, topic configuration, producer/consumer patterns, consumer group management, JMX monitoring setup, log retention tuning, and SASL/SSL security
- `server.properties.annotated` -- annotated KRaft-mode configuration with every directive explained, default values, and guidance on when to change them
