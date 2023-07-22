#!/bin/bash

# Define the default DNS server
DEFAULT_DNS="8.8.8.8"
INSTALL_NVIDIA=false
INSTALL_AMD=false
IP_NEEDED=true

# Display Help function
function display_help() {
    echo "This is a provisioning script which does the following:"
    echo "1. Sets a static IP based on user input (unless --no-ip-needed is specified)."
    echo "2. Upgrades the system."
    echo "3. Installs the latest NVIDIA drivers and CUDA if --nvidia-gpu is specified."
    echo "4. Installs the ROCm for AMD GPUs if --amd-gpu is specified."
    echo "5. Prints a reminder to reboot the system."
    echo "6. Prints commands to check the NVIDIA, CUDA, or ROCm installation."
    echo
    echo "Usage: sudo bash provision.sh --ip [IP_ADDRESS] --gateway [GATEWAY_IP] --interface [INTERFACE] --dns [DNS_SERVER] --no-ip-needed --nvidia-gpu --amd-gpu"
    echo
    echo "Arguments:"
    echo "--ip [IP_ADDRESS]: The static IP address you want to set for this machine. Required unless --no-ip-needed is specified."
    echo "--gateway [GATEWAY_IP]: The IP address of your router, acting as the gateway. Required unless --no-ip-needed is specified."
    echo "--interface [INTERFACE]: The network interface you want to configure. Required unless --no-ip-needed is specified."
    echo "--dns [DNS_SERVER]: The DNS server for your network. Defaults to Google's DNS server (8.8.8.8) if not provided. Required unless --no-ip-needed is specified."
    echo "--no-ip-needed: If set, the script will not configure a static IP address. This option cannot be combined with --ip, --gateway, --interface, or --dns."
    echo "--nvidia-gpu: If set, the script will install NVIDIA drivers and CUDA. This option cannot be combined with --amd-gpu."
    echo "--amd-gpu: If set, the script will install ROCm for AMD GPUs. This option cannot be combined with --nvidia-gpu."
    echo
    echo "You must specify either --nvidia-gpu or --amd-gpu, but not both."
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
        --no-ip-needed ) IP_NEEDED=false
                         ;;
        --nvidia-gpu )   INSTALL_NVIDIA=true
                         ;;
        --amd-gpu )      INSTALL_AMD=true
                         ;;
        --help )         display_help
                         exit
                         ;;
        * )              display_help
                         exit 1
    esac
    shift
done

# If IP, Gateway, or Interface are not provided, but IP_NEEDED is true, display help and exit
if [ "$IP_NEEDED" = true ] && ( [ -z "$IP" ] || [ -z "$GATEWAY" ] || [ -z "$INTERFACE" ] ); then
    echo "Error: --ip, --gateway, and --interface arguments are required unless --no-ip-needed is specified."
    display_help
    exit 1
fi

# If DNS is not provided, set to default
if [ -z "$DNS" ]; then
    DNS=$DEFAULT_DNS
fi

# Validate the IP, Gateway, and DNS arguments if IP_NEEDED is true
if [ "$IP_NEEDED" = true ]; then
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
fi

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
elif [ "$INSTALL_AMD" = true ] ; then
    # Install ROCm
    echo "Installing ROCm..."
    echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install rocm-dkms
    sudo usermod -a -G video $LOGNAME
    echo "ROCm installation completed."

    # Print the commands to check ROCm installation
    echo "After reboot, you can check the ROCm installation by running the following commands:"
    echo "/opt/rocm/bin/rocminfo"
    echo "/opt/rocm/opencl/bin/clinfo"
    echo "rocm-smi"
else
    echo "GPU driver installation was skipped."
fi

# Reboot reminder
echo "Please reboot your system for the changes to take effect."
