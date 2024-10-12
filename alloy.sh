#!/bin/bash

# Modes
INSTALL="install"
CONFIGURE="configure"

# Constants
ALLOY_CONFIG_PATH=/etc/alloy/config.alloy

# Compatibility Detection
# This script is built for OpenSUSE MicroOS and will not work as expected
# on other operating systems. This check is to prevent the script from
# running on unsupported operating systems.

OS=$(cat /etc/os-release | grep -oP '(?<=^ID=).*' | tr -d '"')

if [ "$OS" != "opensuse-microos" ]; then
  echo "This script only runs on openSUSE MicroOS. Your OS is: $OS. If you would like for $OS to be supported, please open an issue on the GitHub repository."
  exit 1
fi

# Install
# When running with the `install` parameter, the script will add
# the Grafana repository and install the Alloy package.
if [ "$1" == "$INSTALL" ]; then

echo "Downloading the Grafana GPG key..."
curl -s -o gpg.key https://rpm.grafana.com/gpg.key

echo "Adding the Grafana Alloy repository..."
transactional-update run rpm --import gpg.key
transactional-update --continue run zypper addrepo https://rpm.grafana.com grafana
transactional-update --continue pkg in alloy

read -p "Installation was successful. The system now needs to reboot in order to apply the new snapshot. After rebooting, run this script again with \"$0 $CONFIGURE\". Would you like to reboot now? (Y/N): " response

if [[ "$response" =~ ^[Yy]$ ]]; then
  reboot
else
  echo "Operation cancelled by user. Please, reboot the system manually to apply the new snapshot then run this script again with \"$0 $CONFIGURE\"."
  exit 1
fi

# Configure
# When running with the `configure` parameter, the script will
# download the default Alloy configuration file, update it with
# the required environment variables, and move it to the correct
# location. The script will also update the systemd service file
# to run Alloy as the root user.
elif [ "$1" == "$CONFIGURE" ]; then

if [ -z "${GCLOUD_RW_API_KEY}" ] || [ -z "${GCLOUD_HOSTED_METRICS_URL}" ] || [ -z "${GCLOUD_HOSTED_METRICS_ID}" ] || [ -z "${GCLOUD_SCRAPE_INTERVAL}" ] || [ -z "${GCLOUD_HOSTED_LOGS_URL}" ] || [ -z "${GCLOUD_HOSTED_LOGS_ID}" ]; then
  echo "Error: One or more required environment variables are not set or are empty. Navigate to your Grafana Cloud instance and use the Docker Integration to get all the required environment variables. See README for further information."
  exit 1
fi

echo "Downloading default Alloy config..."

TMP_CONFIG_FILE="/tmp/config.alloy" 
GRAFANA_ALLOY_CONFIG="https://storage.googleapis.com/cloud-onboarding/alloy/config/config.alloy"
curl -fsSL "${GRAFANA_ALLOY_CONFIG}" -o "${TMP_CONFIG_FILE}"

echo "Updating configuration..."

sed -i -e "s~{GCLOUD_RW_API_KEY}~${GCLOUD_RW_API_KEY}~g" "${TMP_CONFIG_FILE}"
sed -i -e "s~{GCLOUD_HOSTED_METRICS_URL}~${GCLOUD_HOSTED_METRICS_URL}~g" "${TMP_CONFIG_FILE}"
sed -i -e "s~{GCLOUD_HOSTED_METRICS_ID}~${GCLOUD_HOSTED_METRICS_ID}~g" "${TMP_CONFIG_FILE}"
sed -i -e "s~{GCLOUD_SCRAPE_INTERVAL}~${GCLOUD_SCRAPE_INTERVAL}~g" "${TMP_CONFIG_FILE}"
sed -i -e "s~{GCLOUD_HOSTED_LOGS_URL}~${GCLOUD_HOSTED_LOGS_URL}~g" "${TMP_CONFIG_FILE}"
sed -i -e "s~{GCLOUD_HOSTED_LOGS_ID}~${GCLOUD_HOSTED_LOGS_ID}~g" "${TMP_CONFIG_FILE}"

echo "Moving new configuration..."
mv "$ALLOY_CONFIG_PATH" /etc/alloy/config.alloy.bak

mv "${TMP_CONFIG_FILE}" "$ALLOY_CONFIG_PATH"

SERVICE_PATH=$(systemctl show -p FragmentPath alloy.service | cut -d'=' -f2)
echo "Updating Alloy service at $SERVICE_PATH..."
sed -i 's/User=alloy/User=root/g' "$SERVICE_PATH"

read -p "Alloy should now run once manually so that it can generate the required data before it can be used via systemd. The script will now start it: wait for the service to come online and use the Integrations page on Grafana Cloud to check for the connection state. Once the connection is successful, press CTRL+C to quit. Do you want to continue? (Y/N): " response

if [[ "$response" =~ ^[Yy]$ ]]; then
  echo "Starting Alloy service..."
  /usr/bin/alloy run --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy

  echo "Configure Alloy to run as a service..."
  systemctl enable --now alloy
else
  echo "Operation cancelled by user. You can run Alloy manually by using the run command defined in the systemd service file."
  exit 1
fi

# No parameter
# If the script is run without any parameters, the script will
# display a usage message and exit.
else
  echo "Usage: $0 {install|configure}"
  echo "See README for further information."
  exit 1
fi