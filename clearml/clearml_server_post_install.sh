#!/bin/bash

GRAFANA_CPU_LIMIT="0.5"
GRAFANA_MEMORY_LIMIT="2G"
PROMETHEUS_CPU_LIMIT="0.5"
PROMETHEUS_MEMORY_LIMIT="6G"
CLEARML_CPU_LIMIT="1"
CLEARML_MEMORY_LIMIT="8G"
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
  echo "  --grafana-cpu-limit     Set CPU limit for Grafana. Default is $GRAFANA_CPU_LIMIT core."
  echo "  --grafana-memory-limit  Set Memory limit for Grafana. Default is $GRAFANA_MEMORY_LIMIT."
  echo "  --prometheus-cpu-limit  Set CPU limit for Prometheus. Default is $PROMETHEUS_CPU_LIMIT core."
  echo "  --prometheus-memory-limit Set Memory limit for Prometheus. Default is $PROMETHEUS_MEMORY_LIMIT."
  echo "  --clearml-cpu-limit     Set CPU limit for ClearML. Default is $CLEARML_CPU_LIMIT core."
  echo "  --clearml-memory-limit  Set Memory limit for ClearML. Default is $CLEARML_MEMORY_LIMIT."
  echo "  --grafana-admin-password Set admin password for Grafana. Default is $GRAFANA_ADMIN_PASSWORD."
}

while (( "$#" )); do
  case "$1" in
    --grafana-cpu-limit)
      GRAFANA_CPU_LIMIT=$2
      shift 2
      ;;
    --grafana-memory-limit)
      GRAFANA_MEMORY_LIMIT=$2
      shift 2
      ;;
    --prometheus-cpu-limit)
      PROMETHEUS_CPU_LIMIT=$2
      shift 2
      ;;
    --prometheus-memory-limit)
      PROMETHEUS_MEMORY_LIMIT=$2
      shift 2
      ;;
    --clearml-cpu-limit)
      CLEARML_CPU_LIMIT=$2
      shift 2
      ;;
    --clearml-memory-limit)
      CLEARML_MEMORY_LIMIT=$2
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

function update_limits {
  local file=$1
  local service=$2
  local cpu=$3
  local memory=$4

  awk -v service=$service -v cpu=$cpu -v mem=$memory '
  BEGIN {OFS=FS=":"}
  {
    if ($1 ~ service) {
      getline; if ($1 ~ "cpu_limit") {$2 = cpu} 
      getline; if ($1 ~ "mem_limit") {$2 = mem} 
    }
    print $0
  }' $file > tmp && mv tmp $file
}

update_limits $DOCKER_COMPOSE_FILE "apiserver" $CLEARML_CPU_LIMIT $CLEARML_MEMORY_LIMIT
update_limits $MONITORING_FILE "grafana" $GRAFANA_CPU_LIMIT $GRAFANA_MEMORY_LIMIT
update_limits $MONITORING_FILE "prometheus" $PROMETHEUS_CPU_LIMIT $PROMETHEUS_MEMORY_LIMIT

# Add Prometheus as a data source in Grafana
DATA_SOURCE_URL="http://localhost:3000/api/datasources"
DATA_SOURCE_NAME="Prometheus"

cat << EOF > datasource.json
{
    "name":"$DATA_SOURCE_NAME",
    "type":"prometheus",
    "access":"proxy",
    "url":"http://prometheus:9090"
}
EOF

# Add data source to Grafana
curl "$DATA_SOURCE_URL" \
    -X POST \
    -H 'Content-Type: application/json' \
    --data-binary "@datasource.json" \
    -u "admin:$GRAFANA_ADMIN_PASSWORD"

# Create a dashboard
DASHBOARD_URL="http://localhost:3000/api/dashboards/db"

cat << EOF > dashboard.json
{
  "dashboard": {
    "id": null,
    "title": "Prometheus Dashboard",
    "panels": [
      {
        "title": "Uptime",
        "type": "graph",
        "datasource": "$DATA_SOURCE_NAME",
        "targets": [
          { "expr": "up", "refId": "A" }
        ]
      }
    ]
  },
  "overwrite": true
}
EOF

# Add dashboard to Grafana
curl "$DASHBOARD_URL" \
    -X POST \
    -H 'Content-Type: application/json' \
    --data-binary "@dashboard.json" \
    -u "admin:$GRAFANA_ADMIN_PASSWORD"

# Clean up JSON files
rm datasource.json dashboard.json
