#!/bin/sh
# Creates every topic in workers/topics.yaml with its .retry and .dlq companions.
# Runs in the kafka image (no Python there), so it reads the simple YAML with sed.
set -eu
file="${1:-/topics.yaml}"
bootstrap="${KAFKA_BOOTSTRAP:-kafka:9092}"
partitions=$(sed -n 's/^ *partitions: *\([0-9]*\).*/\1/p' "$file" | head -n1)
for topic in $(sed -n 's/^ *- name: *\([A-Za-z0-9._-]*\).*/\1/p' "$file"); do
  for name in "$topic" "$topic.retry" "$topic.dlq"; do
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$bootstrap" --create --if-not-exists \
      --topic "$name" --partitions "${partitions:-3}" --replication-factor 1
  done
done
/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$bootstrap" --list
