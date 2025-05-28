-- Create a distributed table for system.opentelemetry_span_log
CREATE TABLE IF NOT EXISTS default.distributed_opentelemetry_span_log ON CLUSTER 'cluster_1S_2R'
AS system.opentelemetry_span_log
ENGINE = Distributed('cluster_1S_2R', 'system', 'opentelemetry_span_log', rand());

-- Create a view for easier querying of trace data
CREATE OR REPLACE VIEW default.otel_traces ON CLUSTER 'cluster_1S_2R' AS
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
FROM default.distributed_opentelemetry_span_log;

-- Create a view for trace spans with proper formatting for Grafana
CREATE OR REPLACE VIEW default.otel_spans ON CLUSTER 'cluster_1S_2R' AS
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
FROM default.otel_traces;

-- Create a view for service metrics
CREATE OR REPLACE VIEW default.otel_service_metrics ON CLUSTER 'cluster_1S_2R' AS
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
ORDER BY TimeMinute DESC;

-- Create a view for error traces
CREATE OR REPLACE VIEW default.otel_error_traces ON CLUSTER 'cluster_1S_2R' AS
SELECT *
FROM default.otel_traces
WHERE has(SpanAttributes, 'error') OR has(SpanAttributes, 'error.message');

-- Create a helper view for trace ID timestamps
CREATE OR REPLACE VIEW default.otel_traces_trace_id_ts ON CLUSTER 'cluster_1S_2R' AS
SELECT
    TraceId,
    min(Timestamp) AS Start,
    max(Timestamp + Duration / 1000000) AS End,
    toDate(max(Timestamp + Duration / 1000000)) AS finish_date
FROM default.otel_traces
GROUP BY TraceId;