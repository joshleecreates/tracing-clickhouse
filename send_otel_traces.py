#!/usr/bin/env python3
"""
Example script to send OpenTelemetry trace data to ClickHouse
"""

import os
import sys
import uuid
import time
import random
import datetime
import clickhouse_driver

# Configuration
CLICKHOUSE_HOST = "localhost"
CLICKHOUSE_PORT = 9000
CLICKHOUSE_USER = "otel"
CLICKHOUSE_PASSWORD = "otel"
CLICKHOUSE_DATABASE = "default"

def generate_trace_id():
    """Generate a random trace ID"""
    return str(uuid.uuid4())

def generate_span_id():
    """Generate a random span ID"""
    return str(uuid.uuid4().hex[:16])

def generate_sample_trace(service_names=None):
    """Generate a sample trace with multiple spans"""
    if service_names is None:
        service_names = ["frontend", "backend", "database"]
    
    trace_id = generate_trace_id()
    root_span_id = generate_span_id()
    timestamp = datetime.datetime.now()
    
    # Create root span
    spans = [{
        "TraceId": trace_id,
        "SpanId": root_span_id,
        "ParentSpanId": "",
        "ServiceName": service_names[0],
        "SpanName": "GET /api/data",
        "Timestamp": timestamp,
        "Duration": random.randint(50000000, 500000000),  # 50ms to 500ms in nanoseconds
        "SpanAttributes": {"http.method": "GET", "http.url": "/api/data", "http.status_code": "200"},
        "ResourceAttributes": {"service.name": service_names[0], "service.version": "1.0.0"},
        "StatusCode": 0,
        "StatusMessage": ""
    }]
    
    # Create child spans
    for i in range(1, len(service_names)):
        child_span_id = generate_span_id()
        child_timestamp = timestamp + datetime.timedelta(microseconds=random.randint(1000, 5000))
        child_duration = random.randint(10000000, 100000000)  # 10ms to 100ms in nanoseconds
        
        spans.append({
            "TraceId": trace_id,
            "SpanId": child_span_id,
            "ParentSpanId": root_span_id if i == 1 else spans[i-1]["SpanId"],
            "ServiceName": service_names[i],
            "SpanName": f"Process data in {service_names[i]}",
            "Timestamp": child_timestamp,
            "Duration": child_duration,
            "SpanAttributes": {
                "component": service_names[i],
                "operation": "process_data"
            },
            "ResourceAttributes": {
                "service.name": service_names[i],
                "service.version": "1.0.0"
            },
            "StatusCode": 0,
            "StatusMessage": ""
        })
    
    return spans

def insert_spans(client, spans):
    """Insert spans into ClickHouse"""
    # Prepare data for insertion
    data = []
    for span in spans:
        # Convert dictionaries to ClickHouse Map type
        span_attrs = span["SpanAttributes"]
        resource_attrs = span["ResourceAttributes"]
        
        data.append((
            span["TraceId"],
            span["SpanId"],
            span["ParentSpanId"],
            span["ServiceName"],
            span["SpanName"],
            span["Timestamp"],
            span["Duration"],
            span["Timestamp"],  # Start
            span["Timestamp"] + datetime.timedelta(microseconds=span["Duration"] // 1000),  # End
            (span["Timestamp"] + datetime.timedelta(microseconds=span["Duration"] // 1000)).date(),  # finish_date
            span_attrs,
            resource_attrs,
            span["StatusCode"],
            span["StatusMessage"]
        ))
    
    # Insert data
    client.execute(
        """
        INSERT INTO default.otel_traces_local (
            TraceId, SpanId, ParentSpanId, ServiceName, SpanName, 
            Timestamp, Duration, Start, End, finish_date,
            SpanAttributes, ResourceAttributes, StatusCode, StatusMessage
        ) VALUES
        """,
        data
    )
    
    return len(data)

def main():
    """Main function"""
    try:
        # Connect to ClickHouse
        client = clickhouse_driver.Client(
            host=CLICKHOUSE_HOST,
            port=CLICKHOUSE_PORT,
            user=CLICKHOUSE_USER,
            password=CLICKHOUSE_PASSWORD,
            database=CLICKHOUSE_DATABASE
        )
        
        # Generate and insert sample traces
        num_traces = 10
        if len(sys.argv) > 1:
            try:
                num_traces = int(sys.argv[1])
            except ValueError:
                print(f"Invalid number of traces: {sys.argv[1]}")
                sys.exit(1)
        
        total_spans = 0
        for i in range(num_traces):
            service_names = random.sample([
                "frontend", "backend", "database", "auth-service", 
                "payment-service", "inventory-service", "shipping-service"
            ], k=random.randint(2, 4))
            
            spans = generate_sample_trace(service_names)
            spans_inserted = insert_spans(client, spans)
            total_spans += spans_inserted
            
            print(f"Inserted trace {i+1}/{num_traces} with {spans_inserted} spans")
            time.sleep(0.1)  # Small delay between traces
        
        print(f"\nSuccessfully inserted {total_spans} spans across {num_traces} traces")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()