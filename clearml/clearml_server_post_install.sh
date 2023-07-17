#!/bin/bash

GRAFANA_ADMIN_USER="admin"
GRAFANA_ADMIN_PASSWORD="admin"

CONFIG_DIR="/home/$USER/docker-compose-config-clearml-server"
clearml_name="clearml-server"
monitoring_name="monitoring"
DOCKER_COMPOSE_FILE="$CONFIG_DIR/$clearml_name-compose.yml"
MONITORING_FILE="$CONFIG_DIR/$monitoring_name-compose.yml"

print_help() {
  echo "Usage: $0 [options...]"
  echo
  echo "Options:"
  echo "  --grafana-admin-user      Set admin username for Grafana. Default is $GRAFANA_ADMIN_USER."
  echo "  --grafana-admin-password  Set admin password for Grafana. Default is $GRAFANA_ADMIN_PASSWORD."
}

while (( "$#" )); do
  case "$1" in
    --grafana-admin-user)
      GRAFANA_ADMIN_USER=$2
      shift 2
      ;;
    --grafana-admin-password)
      GRAFANA_ADMIN_PASSWORD=$2
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 1
  esac
done

# Function to create a data source in Grafana
create_data_source() {
  local name=$1
  local type=$2
  local url=$3
  local access=$4

  printf "Creating data source: %s\n" "$name"

  curl -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
    -d '{
      "name": "'"$name"'",
      "type": "'"$type"'",
      "url": "'"$url"'",
      "access": "'"$access"'"
    }' \
    "http://localhost:3000/api/datasources"
}

# Function to create a dashboard in Grafana
create_dashboard() {
  local title=$1
  local panels_json=$2

  printf "Creating dashboard: %s\n" "$title"

  curl -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
    -d '{
      "dashboard": {
        "title": "'"$title"'",
        "panels": '$panels_json'
      },
      "overwrite": false
    }' \
    "http://localhost:3000/api/dashboards/db"
}

# Add Prometheus as a data source in Grafana
create_data_source "Prometheus" "prometheus" "http://prometheus:9090" "proxy"
printf "Prometheus data source created.\n"

# Add additional data sources
create_data_source "Elasticsearch" "elasticsearch" "http://elasticsearch:9200" "proxy"
printf "Elasticsearch data source created.\n"

create_data_source "MongoDB" "mongodb" "http://mongodb:27017" "proxy"
printf "MongoDB data source created.\n"

create_data_source "Redis" "redis" "http://redis:6379" "proxy"
printf "Redis data source created.\n"

# Create dashboards
create_dashboard "System Metrics Dashboard" '[
  {
    "title": "CPU Usage",
    "type": "graph",
    "datasource": "Prometheus",
    "targets": [
      { "expr": "cpu_usage", "refId": "A" }
    ]
  },
  {
    "title": "Memory Usage",
    "type": "graph",
    "datasource": "Prometheus",
    "targets": [
      { "expr": "memory_usage", "refId": "B" }
    ]
  }
]'
printf "System Metrics Dashboard created.\n"

create_dashboard "Elasticsearch Dashboard" '[
  {
    "title": "Index Size",
    "type": "graph",
    "datasource": "Elasticsearch",
    "targets": [
      { "expr": "index_size", "refId": "A" }
    ]
  },
  {
    "title": "Documents Count",
    "type": "graph",
    "datasource": "Elasticsearch",
    "targets": [
      { "expr": "documents_count", "refId": "B" }
    ]
  }
]'
printf "Elasticsearch Dashboard created.\n"

create_dashboard "MongoDB Dashboard" '[
  {
    "title": "Collection Size",
    "type": "graph",
    "datasource": "MongoDB",
    "targets": [
      { "expr": "collection_size", "refId": "A" }
    ]
  },
  {
    "title": "Documents Count",
    "type": "graph",
    "datasource": "MongoDB",
    "targets": [
      { "expr": "documents_count", "refId": "B" }
    ]
  }
]'
printf "MongoDB Dashboard created.\n"

create_dashboard "Redis Dashboard" '[
  {
    "title": "Memory Usage",
    "type": "graph",
    "datasource": "Redis",
    "targets": [
      { "expr": "memory_usage", "refId": "A" }
    ]
  },
  {
    "title": "Commands Processed",
    "type": "graph",
    "datasource": "Redis",
    "targets": [
      { "expr": "commands_processed", "refId": "B" }
    ]
  }
]'
printf "Redis Dashboard created.\n"

# Clean up JSON files
rm datasource.json dashboard.json
