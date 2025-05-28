#!/bin/bash

# This script copies the Grafana dashboards to the correct location

echo "Copying Grafana dashboards..."

# Copy the dashboards to the Grafana container
docker cp grafana_dashboards/OpenTelemetry-Traces-Dashboard.json grafana:/var/lib/grafana/dashboards/
docker cp grafana_dashboards/OpenTelemetry-Trace-Detail.json grafana:/var/lib/grafana/dashboards/

echo "Dashboards copied successfully!"
echo ""
echo "You can now access the dashboards at:"
echo "http://localhost:3001/dashboards"