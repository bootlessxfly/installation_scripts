# ClearML Server Installation Scripts

This repository contains a set of scripts that simplify the process of deploying ClearML server and the subsequent setup of Grafana.

## Scripts

- `install_clearml-server.sh`: This script is used to deploy a Docker Compose deployment of ClearML server. It allows for custom configurations like IP setup, Elastic search password, ClearML host IP, and Git credentials for ClearML agent.

- `post_install.sh`: This script is used after the installation of ClearML server to configure Grafana by adding Prometheus as a datasource and creating a basic dashboard.

- `master_script.sh`: This is a wrapper script that calls the other two scripts in order. It takes care of passing the right arguments to them based on the parameters given.

## Usage

1. Start by ensuring all scripts have execution permissions:

    ```bash
    chmod +x install_clearml-server.sh post_install.sh master_script.sh
    ```

2. Then, you can use the master script to perform the entire installation and configuration process. If you need to set up a static IP, use the following command:

    ```bash
    ./master_script.sh --ip your_ip --gateway your_gateway --interface your_interface --dns your_dns --elastic-password your_elastic_password --clearml-host-ip your_clearml_host_ip --clearml-git-user your_clearml_git_user --clearml-git-pass your_clearml_git_pass
    ```

    If you don't need to set up a static IP, use the `--no-ip-config-needed` flag:

    ```bash
    ./master_script.sh --no-ip-config-needed --elastic-password your_elastic_password --clearml-host-ip your_clearml_host_ip --clearml-git-user your_clearml_git_user --clearml-git-pass your_clearml_git_pass
    ```

    Be sure to replace the placeholders with your actual values.

    This script will perform the following actions:

    - Deploy a Docker Compose deployment of ClearML server using `install_clearml-server.sh`
    - After ClearML server is installed, the `post_install.sh` script will configure Grafana by adding Prometheus as a datasource and creating a basic dashboard.

For more detailed usage information for each script, use the `--help` flag:

```bash
./install_clearml-server.sh --help
./post_install.sh --help
./master_script.sh --help
```

Please note that these scripts assume a certain directory structure. Adjust the paths within the scripts if your setup is different.

## Troubleshooting

If you encounter any issues during the execution of these scripts, ensure that:

- All scripts have execution permissions.
- The user executing the scripts has sufficient permissions.
- The placeholders in the commands are replaced with actual values.
- Docker and Docker Compose are installed and functional.
- The `install_clearml-server.sh` and `post_install.sh` scripts are in the correct directories as assumed by `master_script.sh`.
- Network settings (like IP, gateway, DNS) are correct if a static IP setup is being used.
