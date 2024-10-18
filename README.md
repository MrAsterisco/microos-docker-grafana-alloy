# microos-docker-grafana-alloy

This script installs Grafana Alloy on a MicroOS instance to monitor the system or the Docker containers.

Installing Grafana Alloy on MicroOS is not straightforward: while OpenSUSE is officially supported, MicroOS works differently, being a transactional operating system.

> Disclaimer: this script performs various changes to your operating system configuration by adding a new repository, installing Grafana Alloy, and configuring the service to run on boot. Please make sure to understand what the script does before running it on your system. The script is provided as-is and the author is not responsible for any damage to your system or infrastructure caused by running it.

> Note: this script requires to reboot your system to apply new snapshots. Make sure to run the script on a system that can be rebooted without causing any issues.

## Installation

The latest script version can be downloaded from this GitHub repository.

## Running

This script runs in three phases which and requires to reboot the system in between to apply the changes.

### Phase 1: Install

The first phase of the script adds the Grafana Alloy repository (at `https://rpm.grafana.com`) and installs Grafana Alloy. This step is pretty easy and could also be done manually by running the following commands:

```bash
curl -s -o gpg.key https://rpm.grafana.com/gpg.key
transactional-update run rpm --import gpg.key
transactional-update --continue run zypper addrepo https://rpm.grafana.com grafana
transactional-update --continue pkg in alloy
```

The script does with just:

```bash
./alloy.sh install
```

After the installation is complete, the script will ask to reboot the system to apply the new snapshot. You can also cancel and reboot later, but if you're planning to perform other changes, make sure to use `transactional-update --continue` to avoid overwriting the changes the script made.

### Phase 2: Configure

The second phase downloads the appropriate configuration from the Grafana Alloy repository. This configuration is also used in the official Grafana Alloy installation script and it is stored [here]("https://storage.googleapis.com/cloud-onboarding/alloy/config/config.alloy").

In order to run the configuration correctly, the script expects for the following env variables to be defined:

- `GCLOUD_RW_API_KEY`
- `GCLOUD_HOSTED_METRICS_URL`
- `GCLOUD_HOSTED_METRICS_ID`
- `GCLOUD_SCRAPE_INTERVAL`
- `GCLOUD_HOSTED_LOGS_URL`
- `GCLOUD_HOSTED_LOGS_ID`

You can set these variables in the same command that runs the script and their values can be obtained while configuring the Grafana Alloy instance on Grafana Cloud.

To get the correct command, it is recommend to copy/paste all the values directly from Grafana Cloud by following these steps:

1. Go to your Grafana Cloud instance and log in.
2. Click on "Connections" > "Integrations" in the sidebar.
3. Select the Integration you'd like to configure (eg. Docker or Linux Server). If you can't see your Integration, use the "Add new integration" button.
4. Click on the "Configuration details" tab, then scroll down to the second step "Install Grafana Alloy".
5. Click on "Run Grafana Alloy".
6. Generate a new token by providing a name and clicking "Create token".
7. Scroll down to the "Install and run Grafana Alloy" section and copy all the env variables as they're defined. You should copy everything until `/bin/sh -c`.

> You can also try to install Alloy using the official script, but it will fail because of issues with SELinux. This script workarounds this problem by installing Alloy from the official repository and then applying the configuration manually.

You should end up with a command that looks like this:

```bash
ARCH="amd64" GCLOUD_HOSTED_METRICS_URL="https://someURL" GCLOUD_HOSTED_METRICS_ID="123456" GCLOUD_SCRAPE_INTERVAL="60s" GCLOUD_HOSTED_LOGS_URL="https://someOtherURL" GCLOUD_HOSTED_LOGS_ID="123456" GCLOUD_RW_API_KEY="longSequenceOfCharacters" ./alloy.sh configure
```

Do not close the "Alloy configuration" window on Grafana Cloud, as you won't be able to see the values again, but you will also need it to test the Alloy integration.

> Note: the script will fail immediately if any of these env variables are not defined. If Grafana is providing different values, please open an issue on the GitHub repo or try to modify the script accordingly.

The script will then download the configuration, update all the required values, and then configure the `systemd` service to run Alloy.

> By default, the Alloy service is configured to run using the `alloy` user, but this user is not created while installing on MicroOS: the script fixes this by changing the user to `root`. If you're not comfortable running Alloy as `root`, you should create the `alloy` user first and manually modify the `systemd` script by running `systemctl edit --full alloy`.

After the configuration is complete, the script will ask to reboot the system to apply the new snapshot.

### Phase 3: Start

The third phase of the script starts Alloy manually once. This is required for Alloy to create the required folders and files in the system. If you skip this step, the Alloy service will fail to start as SELinux will prevent the script from creating its library in `/var/lib/alloy/data`.

The script does this for you by running:

```bash
./alloy.sh start
```

The output of Alloy will be printed within the same session. In Grafana Cloud, you can use the "Test Alloy integration" to check if data is flowing as expected.

Once you've confirmed Alloy is working, you should hit CTRL+C to quit it. The script will then finish up by enabling and starting the Alloy service. You can check its state by either running the "Test Alloy integration" again or using `systemctl`:

```bash
systemctl status alloy
```

### Done!

The script is done and Alloy is now up and running on your system. The specific integration that you're configuring on Grafana Cloud will provide further instructions on how to modify the Alloy configuration to send specific data.

You can follow the steps there to modify the configuration file at `/etc/alloy/config.yaml` and then restart the service by running:

```bash
systemctl restart alloy
```

> Note: the Docker Integration also includes a section called "Check prerequisites specific to the Docker integration". This is needed if you decide to run Alloy within its own user, instead of `root`. If you just follow the script configuration, you can skip this section.

You can now delete the `alloy.sh` script.

## Compatibility

This script is compatible only with MicroOS. Future changes to MicroOS might break the script, so please open an issue on the GitHub repo if you encounter any problems.

The script will fail if it detects a different operating system.

## Contributions

You are welcome to contribute to this script by opening a pull request on the GitHub repo. Please make sure to test the script on a MicroOS instance before submitting the PR.

If you would like to add support for other operating systems, please open an issue first to discuss the specific use-case: most Linux distributions work out-of-the-box using the official Grafana Alloy script.

## Status

This script is currently being used to configure production machines running Grafana Alloy to monitor a Docker Swarm.

As MicroOS evolves, the script might need to be updated to reflect the changes in the operating system. Please always make sure to use the latest version of MicroOS, as well as this script.

## License

This script is licensed under the MIT License. [See LICENSE](https://github.com/MrAsterisco/microos-docker-grafana-alloy/blob/main/LICENSE) for details.
