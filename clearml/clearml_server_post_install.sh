#!/bin/bash

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
  echo "  --grafana-admin-password Set admin password for Grafana. Default is $GRAFANA_ADMIN_PASSWORD."
}

while (( "$#" )); do
  case "$1" in
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