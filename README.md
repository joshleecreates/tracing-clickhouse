# Open Telemetry Demo for FOSDEM

This repo creates:

* Clickhouse 4-node Cluster with the `system.opentelemetry_span_log` table. This is made possible by setting the session variables `opentelemetry_start_trace_probability: 1`, required for that table to be created. 
* One node Keeper cluster
* Jaeger installation
* Grafana for displaying the traces in a dashboard  

Once created, in this cluster will automatically store trace data for queries in `system.opentelemtry_span_log`

## Useful queries (need to consolidate)

```
SELECT
    lower(hex(trace_id)) AS traceId,
    multiIf(parent_span_id = 0, '', lower(hex(parent_span_id))) AS parentId,
    lower(hex(span_id)) AS id,
    operation_name AS name,
    start_time_us AS timestamp,
    finish_time_us - start_time_us AS duration,
    CAST(tuple('clickhouse'), 'Tuple(serviceName text)') AS localEndpoint,
    attribute['clickhouse.thread_num'] -- get value of this map
FROM system.opentelemetry_span_log
```

Useful view for traces:

```
 CREATE VIEW default.otel_traces_trace_id_ts
(
    `TraceId` UUID,
    `Start` UInt64,
    `End` UInt64
)
AS SELECT
    trace_id AS TraceId,
    min(start_time_us / 1000 / 1000) AS Start,
    max(finish_time_us  / 1000 / 1000) AS End
FROM system.opentelemetry_span_log
GROUP BY TraceId;

CREATE VIEW default.otel_traces
(
    `TraceId` UUID,
    `SpanId` UInt64,
    `ParentSpanId` UInt64,
    `ServiceName` String,
    `SpanName` LowCardinality(String),
    `Timestamp` Float64,
    `Duration` Float64,
    `SpanAttributes` Map(LowCardinality(String), String),
    `ResourceAttributes` Map(LowCardinality(String), String)
)
AS SELECT
    trace_id AS TraceId,
    span_id AS SpanId,
    parent_span_id AS ParentSpanId,
    'ClickHouse' AS ServiceName,
    operation_name AS SpanName,
    (start_time_us / 1000) / 1000 AS Timestamp,
    ((finish_time_us - start_time_us) / 1000) / 1000 AS Duration,
    attribute AS SpanAttributes,
    mapUpdate(attribute, map('server.address', toString(hostname))) AS ResourceAttributes
FROM system.opentelemetry_span_log 
```

Example usage:

```
clickhouse-client --opentelemetry-traceparent "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
```

## Links

[Flame Graph](https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/flame-graph/)
[Debug Hang Queries](https://kb.altinity.com/altinity-kb-useful-queries/debug-hang/)
[Integration with Other Monitoring Systems](https://clickhouse.com/docs/en/operations/opentelemetry#integration-with-monitoring-systems)
[Maciej's query templates](https://www.notion.so/Templates-4cdc78da6450418791a2389eb3bd6337)
[Clickhouse documentation on processors](https://clickhouse.com/docs/en/development/architecture#processors)
[Proccessors header file](https://github.com/ClickHouse/ClickHouse/blob/5280c1f9a99efb2efbf72b7d060182e0a2bb1096/src/Processors/IProcessor.h#L34C5-L34C86)
