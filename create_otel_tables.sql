-- Create a distributed table for system.opentelemetry_span_log
CREATE TABLE IF NOT EXISTS default.distributed_opentelemetry_span_log ON CLUSTER '{cluster}'
AS system.opentelemetry_span_log
ENGINE = Distributed('{cluster}', 'system', 'opentelemetry_span_log');

-- Create a view for easier querying of trace data
CREATE OR REPLACE VIEW default.otel_traces ON CLUSTER '{cluster}'
(
    `TraceId` UUID,
    `SpanId` UInt64,
    `ParentSpanId` UInt64,
    `ServiceName` String,
    `SpanName` LowCardinality(String),
    `Timestamp` DateTime64(3, 'UTC'),
    `FinishTimestamp` DateTime64(3, 'UTC'),
    `FinishDate` Date,
     `Duration` Float64,
    `SpanAttributes` Map(LowCardinality(String), String),
    `ResourceAttributes` Map(LowCardinality(String), String),
    `Hostname` String,
    `Shard` String,
    `Replica` String
)
AS SELECT
    a.trace_id AS TraceId,
    a.span_id AS SpanId,
    a.parent_span_id AS ParentSpanId,
    'ClickHouse' AS ServiceName,
    a.operation_name AS SpanName,
    fromUnixTimestamp64Micro(a.start_time_us) AS Timestamp,
    fromUnixTimestamp64Micro(a.finish_time_us) AS FinishTimestamp,
    finish_date AS FinishDate,
    ((a.finish_time_us - a.start_time_us) / 1000) AS Duration,
    a.attribute AS SpanAttributes,
    if( b.initial_query_id != '' and b.query_id != b.initial_query_id, mapUpdate(mapUpdate(
        a.attribute,
        map('server.address', toString(hostname))),  map('clickhouse.initial_query_id', b.initial_query_id)),
        mapUpdate(a.attribute, map('server.address', toString(hostname)))
    ) AS ResourceAttributes,
    a.hostname AS Hostname,
    _shard_num AS Shard,
    hostname() AS Replica
FROM default.distributed_opentelemetry_span_log a
ASOF LEFT JOIN (SELECT query_id, initial_query_id, event_time, event_date FROM system.query_log WHERE event_date > now() - INTERVAL 14 DAY AND type > 1) b ON a.operation_name = 'query' AND a.attribute['clickhouse.query_id'] = b.query_id AND  fromUnixTimestamp64Micro(a.start_time_us) <= b.event_time;

-- Create a view for trace ID timestamps
CREATE OR REPLACE VIEW default.otel_traces_trace_id_ts ON CLUSTER '{cluster}'
(
    Replica String,
    `TraceId` UUID,
     query_id String,
     query String,
    `Start` DateTime64(3, 'UTC'),
    `End` DateTime64(3, 'UTC')
)
AS SELECT
    Replica,
    TraceId,
    coalesce(nullif(ResourceAttributes['clickhouse.initial_query_id'], ''), SpanAttributes['clickhouse.query_id']) query_id,
    SpanAttributes['db.statement'] query,
    Timestamp Start,
    Timestamp + Duration AS End
FROM  default.otel_traces
WHERE NOT mapContains(ResourceAttributes, 'clickhouse.initial_query_id') AND SpanName = 'query';

-- data tables
CREATE TABLE sessions_local ON CLUSTER '{cluster}'
(
    `app` LowCardinality(String),
    `user_id` String,
    `created_at` DateTime,
    `platform` LowCardinality(String),
    `clicks` UInt32,
    `session_id` UUID
)
ENGINE = ReplicatedMergeTree
PARTITION BY toYYYYMM(created_at)
ORDER BY (app, user_id, session_id, created_at);

CREATE TABLE sessions  ON CLUSTER '{cluster}'
(
    `app` LowCardinality(String),
    `user_id` String,
    `created_at` DateTime,
    `platform` LowCardinality(String),
    `clicks` UInt32,
    `session_id` UUID
)
ENGINE = Distributed('{cluster}', default, sessions_local, cityHash64(app, user_id));

INSERT INTO sessions WITH
    CAST(number % 4, 'Enum8(\'Orange\' = 0, \'Melon\' = 1, \'Red\' = 2, \'Blue\' = 3)') AS app,
    concat('UID: ', leftPad(toString(number % 20000000), 8, '0')) AS user_id,
    toDateTime('2021-10-01 10:11:12') + (number / 300) AS created_at,
    CAST((number + 14) % 3, 'Enum8(\'Bat\' = 0, \'Mice\' = 1, \'Rat\' = 2)') AS platform,
    number % 17 AS clicks,
    generateUUIDv4() AS session_id
SELECT
    app,
    user_id,
    created_at,
    platform,
    clicks,
    session_id
FROM numbers_mt(10000000);






/*CREATE OR REPLACE VIEW default.otel_traces ON CLUSTER 'cluster_2S_2R'
(
    `TraceId` UUID,
    `SpanId` UInt64,
    `ParentSpanId` UInt64,
    `ServiceName` String,
    `SpanName` LowCardinality(String),
    
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
    fromUnixTimestamp64Micro(start_time_us) AS Timestamp,
    ((finish_time_us - start_time_us) / 1000) AS Duration,
    attribute AS SpanAttributes,
    mapUpdate(
        attribute,
        map('server.address', toString(hostname))
    ) AS ResourceAttributes,
    hostname AS Hostname,
    _shard_num AS Shard,
    hostname() AS Replica
FROM clusterAllReplicas('{cluster}', system.opentelemetry_span_log);

-- Example query for retrieving trace data in a format compatible with Jaeger:


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
