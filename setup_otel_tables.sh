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

echo "Running distributed traced query across multiple nodes..."

# Generate trace and span IDs for distributed trace propagation
TRACE_ID=$(head -c 16 /dev/urandom | xxd -p)
SPAN_ID=$(head -c 8 /dev/urandom | xxd -p)

# Run a distributed query with trace context propagation
curl -s "http://localhost:8123/" \
  -H "traceparent: 00-${TRACE_ID}-${SPAN_ID}-01" \
  -d "SELECT count() FROM sessions WHERE app = 'Orange' FORMAT Null SETTINGS opentelemetry_start_trace_probability=1"

echo "Waiting for trace data to flush..."
sleep 8

echo "Trace distribution across nodes:"
curl -s "http://localhost:8123/" -d "
SELECT hostname, count() as spans
FROM default.distributed_opentelemetry_span_log
WHERE lower(hex(trace_id)) = '${TRACE_ID}'
GROUP BY hostname
FORMAT PrettyCompact
"

echo ""
echo "Setup complete. View traces at: http://localhost:3001/d/16d8af9e-4c74-4ae3-b8c3-993c7dd0c6dc/query-trace-details"
