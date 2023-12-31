#!/bin/bash

GRAFANA_API_URL="http://localhost:3000/api"

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
printf "Creating System Metrics Dashboard\n"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
  -d '{
    "dashboard": {
      "title": "System Metrics Dashboard",
      "panels": [
        {
          "title": "Panel 1",
          "type": "graph",
          "datasource": "Prometheus",
          "targets": [
            { "expr": "up", "refId": "A" }
          ]
        }
      ]
    },
    "overwrite": false
  }' \
  "$GRAFANA_API_URL/dashboards/db"