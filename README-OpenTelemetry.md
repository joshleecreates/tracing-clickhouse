# OpenTelemetry Trace Visualization in ClickHouse

This project sets up distributed tables in ClickHouse to visualize OpenTelemetry trace data from all replicas in a cluster.

## Overview

The setup creates distributed tables that pull data from the `system.opentelemetry_span_log` table on all ClickHouse nodes in the cluster. It also creates views to make querying and visualization easier.

## Tables and Views

The following tables and views are created:

1. `default.distributed_opentelemetry_span_log` - A distributed table that pulls data from `system.opentelemetry_span_log` on all nodes
2. `default.otel_traces` - A view that formats the trace data for easier querying
3. `default.otel_traces_trace_id_ts` - A view that stores trace ID timestamps for efficient querying
4. `default.otel_spans` - A view for trace spans with proper formatting for Grafana
5. `default.otel_service_metrics` - A view for service-level metrics
6. `default.otel_error_traces` - A view for error traces

## Schema

The `otel_traces` view has the following schema:

- `TraceId` (UUID) - The unique identifier for the trace
- `SpanId` (UInt64) - The unique identifier for the span
- `ParentSpanId` (UInt64) - The identifier of the parent span (0 for root spans)
- `ServiceName` (String) - The name of the service that generated the span
- `SpanName` (LowCardinality(String)) - The name of the operation represented by the span
- `Timestamp` (Float64) - The start time of the span in seconds since the epoch
- `Duration` (Float64) - The duration of the span in seconds
- `SpanAttributes` (Map(LowCardinality(String), String)) - Key-value pairs of span attributes
- `ResourceAttributes` (Map(LowCardinality(String), String)) - Key-value pairs of resource attributes

## Setup Instructions

1. Make sure your ClickHouse cluster is running:
   ```bash
   docker-compose up -d
   ```

2. Run the setup script to create the tables and views:
   ```bash
   chmod +x setup_otel_tables.sh
   ./setup_otel_tables.sh
   ```

3. Verify that the tables were created:
   ```bash
   docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "SHOW TABLES FROM default"
   ```

4. Import the Grafana dashboards:
   - Open Grafana at http://localhost:3001
   - Go to Dashboards > Import
   - Upload the JSON files from the `grafana_dashboards` directory:
     - `OpenTelemetry-Traces-Dashboard.json`
     - `OpenTelemetry-Trace-Detail.json`
   - When importing, you'll be prompted to select a data source. Choose your ClickHouse data source.

## Querying Trace Data

You can query the trace data using the following examples:

### Get all traces

```sql
SELECT * FROM default.otel_traces LIMIT 10
```

### Get a specific trace

```sql
SELECT * FROM default.otel_traces WHERE TraceId = 'your-trace-id' ORDER BY Timestamp
```

### Get service metrics

```sql
SELECT * FROM default.otel_service_metrics LIMIT 10
```

### Get error traces

```sql
SELECT * FROM default.otel_error_traces LIMIT 10
```

## Grafana Dashboards

Two Grafana dashboards are provided:

1. **OpenTelemetry Traces Dashboard** - An overview of all traces with metrics and visualizations
2. **OpenTelemetry Trace Detail** - A detailed view of a specific trace with a trace visualization

Both dashboards use a configurable data source variable, allowing you to select which ClickHouse data source to use. This makes the dashboards more flexible and reusable across different environments.

## Troubleshooting

If you encounter issues:

1. Check that the ClickHouse cluster is running:
   ```bash
   docker-compose ps
   ```

2. Check the ClickHouse logs:
   ```bash
   docker logs clickhouse-01
   ```

3. Verify that the `system.opentelemetry_span_log` table exists and contains data:
   ```bash
   docker exec -it clickhouse-01 clickhouse-client --user default --password "" -q "SELECT count() FROM system.opentelemetry_span_log"
   ```

4. If the table exists but is empty, you may need to configure your application to send OpenTelemetry data to ClickHouse.

## Additional Resources

- [ClickHouse OpenTelemetry Documentation](https://clickhouse.com/docs/en/operations/opentelemetry)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)