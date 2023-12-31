#!/bin/bash

# Check if running user is root
if [[ $EUID -eq 0 ]]; then
  echo "WARNING: This script is running as root. It is recommended to run it as a non-root user."
fi

# Set default resource limits
GRAFANA_CPU_LIMIT=${GRAFANA_CPU_LIMIT:-"0.5"}
GRAFANA_MEMORY_LIMIT=${GRAFANA_MEMORY_LIMIT:-"2G"}
PROMETHEUS_CPU_LIMIT=${PROMETHEUS_CPU_LIMIT:-"0.5"}
PROMETHEUS_MEMORY_LIMIT=${PROMETHEUS_MEMORY_LIMIT:-"6G"}
# CLEARML_CPU_LIMIT=${CLEARML_CPU_LIMIT:-"1"}
# CLEARML_MEMORY_LIMIT=${CLEARML_MEMORY_LIMIT:-"8G"}

# Default DNS addresses
DNS=${DNS:-"8.8.8.8,8.8.4.4"}
#Default elastic group ID
ELASTIC_GROUPID="1000"

CONFIG_DIR="/home/$USER/docker-compose-config-clearml-server"
clearml_name="clearml-server"
monitoring_name="monitoring"
DOCKER_COMPOSE_FILE="$CONFIG_DIR/$clearml_name-compose.yml"
DOCKER_COMPOSE_PROMETHEUS_EXPORTERS="$CONFIG_DIR/docker-compose.exporters.yml"
MONITORING_FILE="$CONFIG_DIR/$monitoring_name-compose.yml"

# Default values
NO_IP_CONFIG_NEEDED=false
ELASTIC_PASSWORD=""
CLEARML_HOST_IP=""
CLEARML_AGENT_GIT_USER=""
CLEARML_AGENT_GIT_PASS=""

# A function that prints a help menu
print_help() {
  echo "Usage: $0 [OPTIONS]..."
  echo "Deploy a Docker Compose deployment."
  echo "Example: $0 --ip 192.168.1.2 --gateway 192.168.1.1 --interface eth0 --dns 1.1.1.1,1.0.0.1 --purge --elastic-password my_password --clearml-host-ip 192.168.1.2 --clearml-git-user my_user --clearml-git-pass my_pass --grafana-admin-pass admin_pass --grafana-new-user new_user --grafana-new-pass new_pass"
  echo "Example (No IP config): $0 --no-ip-config-needed --purge --elastic-password my_password --clearml-host-ip 192.168.1.3 --clearml-git-user my_user --clearml-git-pass my_pass --grafana-admin-pass admin_pass --grafana-new-user new_user --grafana-new-pass new_pass"
  echo ""
  echo "Options:"
  echo "  --purge                         Purge existing docker compose deployment before deploying."
  echo "  --ip                            The IP address for the static IP setup."
  echo "  --gateway                       The Gateway for the static IP setup."
  echo "  --interface                     The Network Interface for the static IP setup."
  echo "  --dns                           The DNS servers for the static IP setup (optional, defaults to Google's DNS)."
  echo "  --elastic-password              The password for the Elastic search setup.[Mandatory]"
  echo "  --clearml-host-ip               The IP address for the ClearML host.[Mandatory]"
  echo "  --clearml-git-user              The Git username for the ClearML agent.[Mandatory]"
  echo "  --clearml-git-pass              The Git password(API Token) for the ClearML agent.[Mandatory]"
  echo "  --no-ip-config-needed           Skip the IP configuration step.[Mandatory if not providing IP config]"
  echo "  --grafana-cpu-limit             CPU limit for Grafana (optional, defaults to 0.5)"
  echo "  --grafana-memory-limit          Memory limit for Grafana (optional, defaults to 2G)"
  echo "  --prometheus-cpu-limit          CPU limit for Prometheus (optional, defaults to 0.5)"
  echo "  --prometheus-memory-limit       Memory limit for Prometheus (optional, defaults to 6G)"
  echo "  --help                          Display this help and exit."
}

# A function that checks if an IP address is valid
validate_ip() {
  if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid IP format: $1"
    exit 1
  fi
}

# Parse arguments
PURGE=false
IP_ADDRESS=""
GATEWAY=""
INTERFACE=""

while (( "$#" )); do
  case "$1" in
    --purge)
      PURGE=true
      shift
      ;;
    --ip)
      IP_ADDRESS=$2
      validate_ip $IP_ADDRESS
      shift 2
      ;;
    --gateway)
      GATEWAY=$2
      validate_ip $GATEWAY
      shift 2
      ;;
    --interface)
      INTERFACE=$2
      shift 2
      ;;
    --dns)
      DNS=$2
      shift 2
      ;;
    --elastic-password)
      ELASTIC_PASSWORD=$2
      shift 2
      ;;
    --clearml-host-ip)
      CLEARML_HOST_IP=$2
      validate_ip $CLEARML_HOST_IP
      shift 2
      ;;
    --clearml-git-user)
      CLEARML_AGENT_GIT_USER=$2
      shift 2
      ;;
    --clearml-git-pass)
      CLEARML_AGENT_GIT_PASS=$2
      shift 2
      ;;
    --grafana-admin-pass)
      GRAFANA_ADMIN_PASSWORD=$2
      shift 2
      ;;
    --no-ip-config-needed)
      NO_IP_CONFIG_NEEDED=true
      shift
      ;;
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
    --help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

# Check if the Elastic search parameters have been provided
if [ -z "$ELASTIC_PASSWORD" ] || [ -z "$CLEARML_HOST_IP" ] || [ -z "$CLEARML_AGENT_GIT_USER" ] || [ -z "$CLEARML_AGENT_GIT_PASS" ]; then
  echo "You must provide Elastic password, ClearML host IP, ClearML agent git user, ClearML agent git password, Grafana admin password, new Grafana user, and new Grafana user password."
  print_help
  exit 1
fi

# Check if IP, gateway, and interface parameters have been provided
if [ "$NO_IP_CONFIG_NEEDED" == "false" ] && ([ -z "$IP_ADDRESS" ] || [ -z "$GATEWAY" ] || [ -z "$INTERFACE" ]); then
  echo "You must provide an IP address, a gateway, and a network interface, or use the '--no-ip-config-needed' option."
  print_help
  exit 1
fi


# Check if docker compose exists
if command -v docker-compose &> /dev/null; then
    # Check if docker compose has been deployed before
    if [ "$(sudo docker-compose -f $DOCKER_COMPOSE_FILE -f $DOCKER_COMPOSE_PROMETHEUS_EXPORTERS -f $MONITORING_FILE ps -q)" ]; then
      if [ "$PURGE" == "true" ]; then
        echo "Purging existing docker compose deployment..."
        sudo docker-compose -f $DOCKER_COMPOSE_FILE -f $DOCKER_COMPOSE_PROMETHEUS_EXPORTERS -f $MONITORING_FILE down
      else
        echo "Docker compose has already been deployed. If you want to redeploy, remove the existing deployment manually or use the '--purge' option."
        exit 1
      fi
    fi
fi

# Update and upgrade your system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Docker
# Install Docker via apt
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update -y
sudo apt install docker-ce -y
sudo apt install docker-compose -y


# Set up unattended upgrades
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
mkdir $CONFIG_DIR && cd $CONFIG_DIR

# setup a static IP for your router rules
if [ "$NO_IP_CONFIG_NEEDED" == "false" ]; then
  cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$IP_ADDRESS/24]
      routes:
        - to: 0.0.0.0/0
          via: $GATEWAY
      nameservers:
        addresses: [$DNS]
EOF

  sudo netplan apply
fi

#Install ClearML Server using docker-compose
#Get the latest docker-compose file for ClearML
curl -o $DOCKER_COMPOSE_FILE https://raw.githubusercontent.com/allegroai/clearml-server/master/docker/docker-compose.yml

#Create .env file with necessary environment variables
cat <<EOF > .env
ELASTIC_PASSWORD=$ELASTIC_PASSWORD
CLEARML_HOST_IP=$CLEARML_HOST_IP
CLEARML_AGENT_GIT_USER=$CLEARML_AGENT_GIT_USER
CLEARML_AGENT_GIT_PASS=$CLEARML_AGENT_GIT_PASS
EOF

if ! getent group elastic >/dev/null; then
    sudo groupadd -g $ELASTIC_GROUPID elastic
fi

# Add the current user to the 'elastic' group
sudo usermod -a -G $ELASTIC_GROUPID $USER

# Create the Elasticsearch data directory if it doesn't exist
sudo mkdir -p /opt/clearml/data/elastic_7

# Change the ownership of the Elasticsearch data directory
sudo chown -R $ELASTIC_GROUPID:$ELASTIC_GROUPID /opt/clearml/data/elastic_7
sudo chmod -R g+w /opt/clearml/data/elastic_7

# Create Docker Compose File for Prometheus and Grafana
cat <<EOF > $MONITORING_FILE
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - 9090:9090
    volumes:
      - prometheus_data:/etc/prometheus
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - backend
      - frontend
    deploy:
      resources:
        limits:
          cpus: '$PROMETHEUS_CPU_LIMIT'
          memory: $PROMETHEUS_MEMORY_LIMIT

  grafana:
    image: grafana/grafana:latest
    ports:
      - 3000:3000
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - backend
      - frontend
    deploy:
      resources:
        limits:
          cpus: '$GRAFANA_CPU_LIMIT'
          memory: $GRAFANA_MEMORY_LIMIT

volumes:
  prometheus_data:
  grafana_data:
EOF

# Create docker-compose.exporters.yml
cat > $DOCKER_COMPOSE_PROMETHEUS_EXPORTERS << 'EOF'
version: "3.6"
services:
  mongodb_exporter:
    image: bitnami/mongodb-exporter:latest
    networks:
      - backend
    environment:
      MONGODB_URI: mongodb://mongo:27017
    ports:
      - "9216:9216"

  elasticsearch_exporter:
    image: justwatch/elasticsearch_exporter:latest
    networks:
      - backend
    command: --es.uri=http://elasticsearch:9200
    ports:
      - "9108:9108"
      - "9114:9114"

  redis_exporter:
    image: oliver006/redis_exporter:latest
    networks:
      - backend
    command: --redis.addr=redis://redis:6379
    ports:
      - "9121:9121"
EOF

# Prometheus config
# Create Prometheus config file
cat <<EOF > $CONFIG_DIR/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'mongodb'
    static_configs:
      - targets: ['mongodb_exporter:9216']

  - job_name: 'elasticsearch'
    static_configs:
      - targets: ['elasticsearch_exporter:9114']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis_exporter:9121']
EOF

# Deploy clearml stack with docker compose
sudo docker-compose -f $DOCKER_COMPOSE_FILE -f $DOCKER_COMPOSE_PROMETHEUS_EXPORTERS -f $MONITORING_FILE up -d

# Use cat to create the script file
cat <<EOF > $CONFIG_DIR/clearml-manager.sh
#!/bin/bash
echo "This script is used to manage the state of the cluster deployed with the clearml/monitoring compose"
clearml='$DOCKER_COMPOSE_FILE'
exporters='$DOCKER_COMPOSE_PROMETHEUS_EXPORTERS'
monitors='$MONITORING_FILE'

start() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors up -d
}

stop() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors down
}

restart() {
    stop
    start
}

logs() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors logs
}

pull() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors pull
}

ps() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors ps
}

exec() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors exec "$@"
}

config() {
    sudo docker-compose -f \$clearml -f \$exporters -f \$monitors config
}

case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    pull)
        pull
        ;;
    ps)
        ps
        ;;
    exec)
        shift  # remove the first parameter
        exec "$@"
        ;;
    config)
        config
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart|logs|pull|ps|exec|config}"
        exit 1
esac

EOF

# Make the script executable
chmod +x clearml_stack.sh


echo "Please view logs of your deployment with:"
echo "sudo docker-compose -f $DOCKER_COMPOSE_FILE -f $DOCKER_COMPOSE_PROMETHEUS_EXPORTERS -f $MONITORING_FILE logs"

echo "Please run other commands as:"
echo "sudo docker-compose -f $DOCKER_COMPOSE_FILE -f $DOCKER_COMPOSE_PROMETHEUS_EXPORTERS -f $MONITORING_FILE [command]"
