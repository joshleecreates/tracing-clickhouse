# ClickHouse Distributed Query Tracing

Visualize ClickHouse query execution with OpenTelemetry traces spanning multiple nodes.

## Quick Start

```bash
./init.sh
```

This will:
1. Start a 4-node ClickHouse cluster with Grafana
2. Create the distributed tracing tables and views
3. Load sample data into the `sessions` table
4. Run a traced distributed query across multiple nodes

Open the dashboard at: http://localhost:3001/d/16d8af9e-4c74-4ae3-b8c3-993c7dd0c6dc/query-trace-details

## Architecture

- **clickhouse-01, clickhouse-02**: Shard 1 (replicas)
- **clickhouse-03, clickhouse-04**: Shard 2 (replicas)
- **clickhouse-keeper-01**: Coordination
- **grafana**: Visualization (port 3001)

## Running Traced Queries

### Single Node Trace

Queries run with the `otel` user are automatically traced:

```bash
docker exec -i clickhouse-01 clickhouse-client --user otel --password otel \
  -q "SELECT count() FROM sessions WHERE app = 'Orange'"
```

### Distributed Trace (Multi-Node)

To trace a query across multiple nodes, pass the `traceparent` header:

```bash
TRACE_ID=$(head -c 16 /dev/urandom | xxd -p)
SPAN_ID=$(head -c 8 /dev/urandom | xxd -p)

curl -s "http://localhost:8123/" \
  -H "traceparent: 00-${TRACE_ID}-${SPAN_ID}-01" \
  -d "SELECT count() FROM sessions WHERE app = 'Orange' FORMAT Null SETTINGS opentelemetry_start_trace_probability=1"
```

Wait ~8 seconds for traces to flush, then view in Grafana.

## Tables and Views

| Table/View | Description |
|------------|-------------|
| `distributed_opentelemetry_span_log` | Distributed table aggregating span logs from all nodes |
| `otel_traces` | View with formatted trace data including hostname, shard, replica |
| `otel_traces_trace_id_ts` | View for selecting traced queries by query_id |
| `sessions` | Sample distributed table for testing queries |

## Dashboard

The Grafana dashboard shows:
1. **Traces** - Timeline of traced queries
2. **Available traced queries** - Table of queries with trace data
3. **Traced query** - Details of selected query
4. **Trace detail** - Span visualization showing execution across nodes

## Key Files

- `init.sh` - Main setup script
- `setup_otel_tables.sh` - Creates tables/views and runs sample traced queries
- `create_otel_tables.sql` - SQL definitions for distributed tracing tables
- `sample_query.sql` - Sample query for testing
- `grafana_dashboards/Query_Trace_details.json` - Grafana dashboard

## Trace Format Notes

The Grafana traces panel requires:
- `startTime`: milliseconds since epoch (integer)
- `duration`: milliseconds (integer)

Sub-millisecond precision is lost due to plugin limitations.

## Links

- [ClickHouse OpenTelemetry Documentation](https://clickhouse.com/docs/en/operations/opentelemetry)
- [Grafana Traces Panel](https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/traces/)
