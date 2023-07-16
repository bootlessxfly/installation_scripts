#!/bin/bash

IP=""
GATEWAY=""
INTERFACE=""
DNS=""
PURGE=false
ELASTIC_PASSWORD=""
CLEARML_HOST_IP=""
CLEARML_GIT_USER=""
CLEARML_GIT_PASS=""
GRAFANA_ADMIN_PASS="admin"
NO_IP_CONFIG_NEEDED=false
# Get the absolute path of the calling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Set the CLEARML_SCRIPT_PATH variable
CLEARML_SCRIPT_PATH="$SCRIPT_DIR/install_clearml-server.sh"

print_help() {
  echo "Usage: $0 [options...]"
  echo
  echo "Options:"
  echo "  --ip                    The IP address for the static IP setup."
  echo "  --gateway               The Gateway for the static IP setup."
  echo "  --interface             The Network Interface for the static IP setup."
  echo "  --dns                   The DNS servers for the static IP setup."
  echo "  --purge                 Purge existing docker compose deployment before deploying."
  echo "  --elastic-password      The password for the Elastic search setup."
  echo "  --clearml-host-ip       The IP address for the ClearML host."
  echo "  --clearml-git-user      The Git username for the ClearML agent."
  echo "  --clearml-git-pass      The Git password(API Token) for the ClearML agent."
  echo "  --grafana-admin-pass    The Grafana admin password. Defaults to 'admin'"
  echo "  --no-ip-config-needed   Skip the IP configuration step."
  echo "  --help                  Display this help and exit."
}

while (( "$#" )); do
  case "$1" in
    --ip)
      IP=$2
      shift 2
      ;;
    --gateway)
      GATEWAY=$2
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
      CLEARML_GIT_USER=$2
      shift 2
      ;;
    --clearml-git-pass)
      CLEARML_GIT_PASS=$2
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

# Construct the ClearML installation script command
CLEARML_INSTALL_CMD="bash $CLEARML_SCRIPT_PATH "

if [[ $NO_IP_CONFIG_NEEDED == true ]]; then
  CLEARML_INSTALL_CMD+="--no-ip-config-needed "
else
  CLEARML_INSTALL_CMD+="--ip $IP --gateway $GATEWAY --interface $INTERFACE --dns $DNS "
fi

CLEARML_INSTALL_CMD+="--elastic-password $ELASTIC_PASSWORD --clearml-host-ip $CLEARML_HOST_IP --clearml-git-user $CLEARML_GIT_USER --clearml-git-pass $CLEARML_GIT_PASS "

if [[ $PURGE == true ]]; then
  CLEARML_INSTALL_CMD+="--purge"
fi

# Call the ClearML installation script
eval $CLEARML_INSTALL_CMD

# Call the post-installation script
bash post_install.sh --grafana-admin-password $GRAFANA_ADMIN_PASS