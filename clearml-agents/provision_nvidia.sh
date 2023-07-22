#!/bin/bash

# Define the default DNS server
DEFAULT_DNS="8.8.8.8"
INSTALL_NVIDIA=true

# Display Help function
function display_help() {
    echo "This is a provisioning script which does the following:"
    echo "1. Sets a static IP based on user input."
    echo "2. Upgrades the system."
    echo "3. Installs the latest NVIDIA drivers and CUDA (unless --no-nvidia is specified)."
    echo "4. Prints a reminder to reboot the system."
    echo "5. Prints commands to check the NVIDIA and CUDA installation."
    echo
    echo "Usage: sudo bash provision.sh --ip [IP_ADDRESS] --gateway [GATEWAY_IP] --interface [INTERFACE] --dns [DNS_SERVER] --no-nvidia"
    echo
    echo "Arguments:"
    echo "--ip [IP_ADDRESS]: The static IP address you want to set for this machine."
    echo "--gateway [GATEWAY_IP]: The IP address of your router, acting as the gateway."
    echo "--interface [INTERFACE]: The network interface you want to configure."
    echo "--dns [DNS_SERVER]: The DNS server for your network. Defaults to Google's DNS server (8.8.8.8) if not provided."
    echo "--no-nvidia: If set, the script will not install NVIDIA drivers and CUDA."
    echo
}

# Function to validate IP addresses
function validate_ip() {
    if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($1)
        IFS=$OIFS
        if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Parse command line options
while [ "$1" != "" ]; do
    case $1 in
        --ip )           shift
                         IP=$1
                         ;;
        --gateway )      shift
                         GATEWAY=$1
                         ;;
        --interface )    shift
                         INTERFACE=$1
                         ;;
        --dns )          shift
                         DNS=$1
                         ;;
        --no-nvidia )    INSTALL_NVIDIA=false
                         ;;
        --help )         display_help
                         exit
                         ;;
        * )              display_help
                         exit 1
    esac
    shift
done

# If IP, Gateway or Interface are not provided, display help and exit
if [ -z "$IP" ] || [ -z "$GATEWAY" ] || [ -z "$INTERFACE" ]; then
    echo "Error: --ip, --gateway and --interface arguments are required."
    display_help
    exit 1
fi

# If DNS is not provided, set to default
if [ -z "$DNS" ]; then
    DNS=$DEFAULT_DNS
fi

# Validate the IP, Gateway and DNS arguments
validate_ip $IP
if [ $? -ne 0 ]; then
    echo "Error: IP is not valid. Please provide a valid IP address."
    display_help
    exit 1
fi
validate_ip $GATEWAY
if [ $? -ne 0 ]; then
    echo "Error: Gateway IP is not valid. Please provide a valid IP address."
    display_help
    exit 1
fi
validate_ip $DNS
if [ $? -ne 0 ]; then
    echo "Error: DNS server IP is not valid. Please provide a valid IP address."
    display_help
    exit 1
fi

echo "Setting static IP to $IP with gateway $GATEWAY for interface $INTERFACE and DNS server $DNS"
cat > /etc/netplan/$INTERFACE-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$IP/24]
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS]
EOF

# Apply netplan
netplan apply

apt-get install -y alsa-utils

# Upgrade the system
echo "Upgrading the system..."
apt-get update && apt-get upgrade -y

if [ "$INSTALL_NVIDIA" = true ] ; then
    # Install NVIDIA drivers and CUDA
    echo "Installing latest NVIDIA drivers and CUDA..."
    add-apt-repository ppa:graphics-drivers/ppa -y
    apt-get update
    ubuntu-drivers autoinstall
    apt-get install -y nvidia-cuda-toolkit
    echo "NVIDIA drivers and CUDA installation completed."

    # Print the commands to check CUDA installation
    echo "After reboot, you can check the NVIDIA and CUDA installation by running the following commands:"
    echo "lsmod | grep nvidia"
    echo "nvidia-smi"
else
    echo "NVIDIA installation was skipped."
fi

# Reboot reminder
echo "Please reboot your system for the changes to take effect."
