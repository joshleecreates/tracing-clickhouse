#!/bin/bash
set -e

echo "Setting up OpenTelemetry tables in ClickHouse..."

# Execute the SQL file on clickhouse-01
echo "Executing on clickhouse-01..."
docker exec -i clickhouse-01 clickhouse-client --multiquery < create_otel_tables.sql

echo "OpenTelemetry tables setup completed."
echo "You can now use the distributed tables and views for OpenTelemetry data."