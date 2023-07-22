#!/bin/bash

# Help function
function print_help {
    echo "Usage: $0 --nvidia-gpu | --amd-gpu | --link_server --ip_address <IP_ADDRESS> --access_key <ACCESS_KEY> --secret_key <SECRET_KEY>"
    echo "If --link_server is used, all parameters are required."
    echo "If --link_server is not used, no parameters are required."
    echo "You must specify either --nvidia-gpu or --amd-gpu, but not both."
    exit 1
}

LINK_SERVER=false
GPU_NVIDIA=false
GPU_AMD=false

while (( "$#" )); do
  case "$1" in
    --nvidia-gpu)
      GPU_NVIDIA=true
      shift
      ;;
    --amd-gpu)
      GPU_AMD=true
      shift
      ;;
    --link_server)
      LINK_SERVER=true
      shift
      ;;
    --access_key)
      ACCESS_KEY=$2
      shift 2
      ;;
    --secret_key)
      SECRET_KEY=$2
      shift 2
      ;;
    --ip_address)
      IP_ADDRESS=$2
      shift 2
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown parameter passed: $1"
      print_help
      exit 1
      ;;
  esac
done

# Validation
if $LINK_SERVER && ( $GPU_NVIDIA || $GPU_AMD ) ; then
    echo "Error: --nvidia-gpu or --amd-gpu cannot be combined with --link_server."
    print_help
    exit 1
fi

if ( $GPU_NVIDIA && $GPU_AMD ) ; then
    echo "Error: --nvidia-gpu and --amd-gpu cannot be used at the same time."
    print_help
    exit 1
fi

if ! ( $LINK_SERVER || $GPU_NVIDIA || $GPU_AMD ) ; then
    echo "Error: Either --nvidia-gpu, --amd-gpu or --link_server must be specified."
    print_help
    exit 1
fi

sudo apt-get install python3 -y
sudo apt-get install python3-pip -y

# Installation of ClearML Agent
echo "Installing ClearML Agent..."
pip3 install clearml-agent

pip3 install clearml

# Installation of PyTorch framework
if $GPU_NVIDIA ; then
  echo "Installing PyTorch for Nvidia GPU..."
  pip3 install torch
elif $GPU_AMD ; then
  echo "Installing PyTorch for AMD GPU..."
  pip3 install torch torchvision torchaudio -f https://download.pytorch.org/whl/rocm4.2/torch_stable.html
fi

echo "Installing numpy"
pip3 install numpy

# GPU Load generation
if $GPU_NVIDIA ; then
  echo "Creating GPU Load Script for Nvidia GPU..."
  cat <<EOF > gpu_load.py
import torch
import time

print('Check if Cuda is available on the machine')
print(torch.cuda.is_available())

# Size of the matrix to multiply
size = 10000

# Initialize a large matrix with random values
matrix1 = torch.randn(size, size, device='cuda')
matrix2 = torch.randn(size, size, device='cuda')

# Start the timer
start = time.time()

# Perform the matrix multiplication
product = torch.matmul(matrix1, matrix2)

# Call item to force synchronizing and calculate the operation time
item = product[0, 0].item()

# Stop the timer
end = time.time()

# Print the operation time
print('Matrix multiplication time: {} s'.format(end - start))
print('SUCESS: cuda and matrix multiplication test has passed!!')

EOF
elif $GPU_AMD ; then
  echo "Creating GPU Load Script for AMD GPU..."
  cat <<EOF > gpu_load.py
import torch
import time

# Check for ROCm
print('Check if ROCm is available on the machine')
print(torch.backends.rocm.is_available())

# Size of the matrix to multiply
size = 10000

# Initialize a large matrix with random values
matrix1 = torch.randn(size, size, device='rocm')
matrix2 = torch.randn(size, size, device='rocm')

# Start the timer
start = time.time()

# Perform the matrix multiplication
product = torch.matmul(matrix1, matrix2)

# Call item to force synchronizing and calculate the operation time
item = product[0, 0].item()

# Stop the timer
end = time.time()

# Print the operation time
print('Matrix multiplication time: {} s'.format(end - start))
print('SUCESS: ROCm and matrix multiplication test has passed!!')

EOF
fi

# Running GPU load
echo "Running GPU Load..."
python3 gpu_load.py

# Print GPU load
if $GPU_NVIDIA ; then
  echo "Printing GPU Load for Nvidia GPU..."
  nvidia-smi
elif $GPU_AMD ; then
  echo "Printing GPU Load for AMD GPU..."
  rocm-smi
fi

if $LINK_SERVER ; then
    if [[ -z "$IP_ADDRESS" || -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]] ; then
        print_help
    fi

# Convert the IP address to the server URLs
API_SERVER="http://${IP_ADDRESS}:8008"
WEB_SERVER="http://${IP_ADDRESS}:8080"
FILES_SERVER="http://${IP_ADDRESS}:8081"

# Create the ClearML configuration file
echo "Creating ClearML Configuration File..."
mkdir -p ~/.clearml
cat << EOF > ~/.clearml/clearml.conf
api {
    # Set for api server and web server
    api_server: $API_SERVER
    web_server: $WEB_SERVER
    files_server: $FILES_SERVER
    # Set for credentials (from profile)
    credentials {
        "access_key" = "$ACCESS_KEY"
        "secret_key" = "$SECRET_KEY"
    }
}
EOF
ln -s ~/.clearml/clearml.conf ~/clearml.conf

    # Starting ClearML Agent
    echo "Starting ClearML Agent..."
    clearml-agent daemon --queue default &
    
    echo "Creating ClearML GPU Load Task Script..."
    cat <<EOF > clearml_gpu_load_task.py
from clearml import Task
task = Task.init(project_name='GPU Test', task_name='gpu load test')
task.execute_remotely(queue_name='default')
import torch
torch.cuda.manual_seed(123)
if torch.cuda.is_available():
    tensor = torch.rand(5000,5000).cuda()
    _ = tensor*tensor
EOF

    # Running ClearML GPU load
    echo "Running ClearML GPU Load..."
    timeout 14 python3 clearml_gpu_load_task.py &

    # Print GPU load
    echo "Printing GPU Load..."
    if $GPU_NVIDIA ; then
      nvidia-smi
    elif $GPU_AMD ; then
      rocm-smi
    fi
fi
