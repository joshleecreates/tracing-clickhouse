-- Create a distributed table for system.opentelemetry_span_log
CREATE TABLE IF NOT EXISTS default.distributed_opentelemetry_span_log ON CLUSTER 'cluster_2S_2R'
AS system.opentelemetry_span_log
ENGINE = Distributed('cluster_2S_2R', 'system', 'opentelemetry_span_log', rand());

-- Create a view for trace ID timestamps
CREATE OR REPLACE VIEW default.otel_traces_trace_id_ts ON CLUSTER 'cluster_2S_2R'
(
    `TraceId` UUID,
    `Start` UInt64,
    `End` UInt64
)
AS SELECT
    trace_id AS TraceId,
    min(start_time_us / 1000) AS Start,
    max(finish_time_us  / 1000) AS End
FROM default.distributed_opentelemetry_span_log
GROUP BY TraceId;

-- Create a view for easier querying of trace data
CREATE OR REPLACE VIEW default.otel_traces ON CLUSTER 'cluster_2S_2R'
(
    `TraceId` UUID,
    `SpanId` UInt64,
    `ParentSpanId` UInt64,
    `ServiceName` String,
    `SpanName` LowCardinality(String),
    `Timestamp` Float64,
    `Duration` Float64,
    `SpanAttributes` Map(LowCardinality(String), String),
    `ResourceAttributes` Map(LowCardinality(String), String),
    `Hostname` String,
    `Shard` String,
    `Replica` String
)
AS SELECT
    trace_id AS TraceId,
    span_id AS SpanId,
    parent_span_id AS ParentSpanId,
    'ClickHouse' AS ServiceName,
    operation_name AS SpanName,
    (start_time_us / 1000) AS Timestamp,
    ((finish_time_us - start_time_us) / 1000) AS Duration,
    attribute AS SpanAttributes,
    mapUpdate(
        attribute,
        map('server.address', toString(hostname))
    ) AS ResourceAttributes,
    hostname AS Hostname,
    _shard_num AS Shard
FROM clusterAllReplicas('{cluster}', system.opentelemetry_span_log);

-- Example query for retrieving trace data in a format compatible with Jaeger:
/*
SELECT
    lower(hex(trace_id)) AS traceId,
    multiIf(parent_span_id = 0, '', lower(hex(parent_span_id))) AS parentId,
    lower(hex(span_id)) AS id,
    operation_name AS name,
    start_time_us AS timestamp,
    finish_time_us - start_time_us AS duration,
    CAST(tuple('clickhouse'), 'Tuple(serviceName text)') AS localEndpoint,
    attribute['clickhouse.thread_num'], -- get value of this map
    hostname,
    shard_num,
    replica_num
FROM default.distributed_opentelemetry_span_log
*/
