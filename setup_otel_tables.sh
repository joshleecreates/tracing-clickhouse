#!/bin/bash

# This script executes the SQL commands to create distributed tables for OpenTelemetry data

echo "Setting up distributed OpenTelemetry tables in ClickHouse..."

# Create the distributed table for system.opentelemetry_span_log
docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "
CREATE TABLE IF NOT EXISTS default.distributed_opentelemetry_span_log AS system.opentelemetry_span_log
ENGINE = Distributed('cluster_1S_2R', 'system', 'opentelemetry_span_log', rand())
"

# Create the otel_traces view
docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "
CREATE OR REPLACE VIEW default.otel_traces AS
SELECT
    trace_id AS TraceId,
    span_id AS SpanId,
    parent_span_id AS ParentSpanId,
    operation_name AS SpanName,
    service_name AS ServiceName,
    start_time_us / 1000000 AS Timestamp,
    (finish_time_us - start_time_us) AS Duration,
    attribute AS SpanAttributes,
    resource AS ResourceAttributes
FROM default.distributed_opentelemetry_span_log
"

# Create the otel_spans view
docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "
CREATE OR REPLACE VIEW default.otel_spans AS
SELECT
    TraceId,
    SpanId,
    ParentSpanId,
    ServiceName,
    SpanName as OperationName,
    Timestamp as StartTime,
    Duration,
    SpanAttributes,
    ResourceAttributes
FROM default.otel_traces
"

# Create the otel_service_metrics view
docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "
CREATE OR REPLACE VIEW default.otel_service_metrics AS
SELECT
    ServiceName,
    SpanName,
    toStartOfMinute(toDateTime(Timestamp)) AS TimeMinute,
    count() AS SpanCount,
    avg(Duration) AS AvgDuration,
    min(Duration) AS MinDuration,
    max(Duration) AS MaxDuration
FROM default.otel_traces
GROUP BY ServiceName, SpanName, TimeMinute
ORDER BY TimeMinute DESC
"

# Create the otel_error_traces view
docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "
CREATE OR REPLACE VIEW default.otel_error_traces AS
SELECT *
FROM default.otel_traces
WHERE has(SpanAttributes, 'error') OR has(SpanAttributes, 'error.message')
"

# Create the otel_traces_trace_id_ts view
docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "
CREATE OR REPLACE VIEW default.otel_traces_trace_id_ts AS
SELECT
    TraceId,
    min(Timestamp) AS Start,
    max(Timestamp + Duration / 1000000) AS End,
    toDate(max(Timestamp + Duration / 1000000)) AS finish_date
FROM default.otel_traces
GROUP BY TraceId
"

echo "Tables created successfully!"
echo ""
echo "To verify the tables were created, run:"
echo "docker exec -it clickhouse-01 clickhouse-client --user default --password \"\" -q \"SHOW TABLES FROM default\""
echo ""
echo "To query trace data, you can run:"
echo "docker exec -it clickhouse-01 clickhouse-client --user default --password \"\" -q \"SELECT * FROM default.otel_traces LIMIT 10\""