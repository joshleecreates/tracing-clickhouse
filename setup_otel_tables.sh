#!/bin/bash
set -e

echo "Setting up OpenTelemetry tables in ClickHouse..."

# force opentelemetry table creation
for i in $(seq 1 4);
do
  docker exec -i clickhouse-0$i clickhouse-client --user otel --password otel --query "SELECT 1" > /dev/null
done

sleep 10

for i in $(seq 1 4);
do
  docker exec -i clickhouse-0$i clickhouse-client --query "TRUNCATE system.opentelemetry_span_log" > /dev/null
done

# Execute the SQL file on clickhouse-01
echo "Executing on clickhouse-01..."
docker exec -i clickhouse-01 clickhouse-client --multiquery < create_otel_tables.sql > /dev/null

echo "OpenTelemetry tables setup completed."

# sample otel query
docker exec -i clickhouse-01 clickhouse-client  --user otel --password otel < sample_query.sql > /dev/null

echo "You can now use the distributed tables and views for OpenTelemetry data."
