#!/bin/bash

IP=""
GATEWAY=""
INTERFACE=""
DNS=""
PURGE=false
ELASTIC_PASSWORD=""
CLEARML_HOST_IP=""
CLEARML_AGENT_GIT_USER=""
CLEARML_AGENT_GIT_PASS=""
GRAFANA_ADMIN_PASS="admin"
NO_IP_CONFIG_NEEDED=false
# Get the absolute path of the calling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Set the CLEARML_SCRIPT_PATH variable
CLEARML_SCRIPT_PATH="$SCRIPT_DIR/deploy_clearml-server_cluster.sh"

CLEARML_POST_INSTALL="$SCRIPT_DIR/clearml_server_post_install.sh"

print_help() {
  echo "Usage: $0 [options...]"
  echo
  echo "Options:"
  echo "  --ip                    The IP address for the static IP setup. [MANDATORY]"
  echo "  --gateway               The Gateway for the static IP setup. [MANDATORY]"
  echo "  --interface             The Network Interface for the static IP setup. [MANDATORY]"
  echo "  --dns                   The DNS servers for the static IP setup."
  echo "  --purge                 Purge existing docker compose deployment before deploying."
  echo "  --elastic-password      The password for the Elastic search setup. [MANDATORY]"
  echo "  --clearml-host-ip       The IP address for the ClearML host. [MANDATORY]"
  echo "  --clearml-git-user      The Git username for the ClearML agent. [MANDATORY]"
  echo "  --clearml-git-pass      The Git password(API Token) for the ClearML agent. [MANDATORY]"
  echo "  --grafana-admin-pass    The Grafana admin password. Defaults to 'admin'"
  echo "  --no-ip-config-needed   Skip the IP configuration step. [Makes IP config not mandatory]"
  echo "  --help                  Display this help and exit."
}


# A function that checks if an IP address is valid
validate_ip() {
  if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid IP format: $1"
    exit 1
  fi
}

while (( "$#" )); do
  case "$1" in
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
    --purge)
      PURGE=true
      shift 1
      ;;
    --elastic-password)
      ELASTIC_PASSWORD=$2
      shift 2
      ;;
    --clearml-host-ip)
      CLEARML_HOST_IP=$2
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
      GRAFANA_ADMIN_PASS=$2
      shift 2
      ;;
    --no-ip-config-needed)
      NO_IP_CONFIG_NEEDED=true
      shift 1
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 1
  esac
done

# Check if the Elastic search parameters have been provided
if [ -z "$ELASTIC_PASSWORD" ] || [ -z "$CLEARML_HOST_IP" ] || [ -z "$CLEARML_AGENT_GIT_USER" ] || [ -z "$CLEARML_AGENT_GIT_PASS" ]; then
  echo "You must provide Elastic password, ClearML host IP, ClearML agent git user, ClearML agent git password."
  print_help
  exit 1
fi

# Check if IP, gateway, and interface parameters have been provided
if [ "$NO_IP_CONFIG_NEEDED" == "false" ] && ([ -z "$IP_ADDRESS" ] || [ -z "$GATEWAY" ] || [ -z "$INTERFACE" ]); then
  echo "You must provide an IP address, a gateway, and a network interface, or use the '--no-ip-config-needed' option."
  print_help
  exit 1
fi

# Construct the ClearML installation script command
CLEARML_INSTALL_CMD="bash $CLEARML_SCRIPT_PATH "

if [[ $NO_IP_CONFIG_NEEDED == true ]]; then
  CLEARML_INSTALL_CMD+="--no-ip-config-needed "
else
  CLEARML_INSTALL_CMD+="--ip $IP --gateway $GATEWAY --interface $INTERFACE --dns $DNS "
fi

CLEARML_INSTALL_CMD+="--elastic-password $ELASTIC_PASSWORD --clearml-host-ip $CLEARML_HOST_IP --clearml-git-user $CLEARML_AGENT_GIT_USER --clearml-git-pass $CLEARML_AGENT_GIT_PASS "

if [[ $PURGE == true ]]; then
  CLEARML_INSTALL_CMD+="--purge"
fi

# Call the ClearML installation script
eval $CLEARML_INSTALL_CMD

# Call the post-installation script
bash $CLEARML_POST_INSTALL --grafana-admin-password $GRAFANA_ADMIN_PASS