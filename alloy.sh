#!/bin/bash

if [ "$(cat /etc/os-release | grep -oP '(?<=^NAME=).*')" != "openSUSE MicroOS" ]; then
  echo "This script only runs on openSUSE microOS."
  exit 1
fi

if [ "$1" == "install" ]; then

echo "Downloading the Grafana GPG key..."
curl -s -o gpg.key https://rpm.grafana.com/gpg.key

echo "Adding the Grafana Alloy repository..."
transactional-update run rpm --import gpg.key; zypper addrepo https://rpm.grafana.com grafana; pkg in alloy

echo "Alloy has been installed successfully! Please reboot the machine to apply the new snapshot, then run this script again with the configure argument."

elif [ "$1" == "configure" ]; then

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
mv /etc/alloy/config.alloy /etc/alloy/config.alloy.bak

mv "${TMP_CONFIG_FILE}" /etc/alloy/config.alloy

echo "Updating systemd service..."
sed -i 's/User=alloy/User=root/g' /etc/systemd/system/alloy.service

read -p "Alloy should now run once manually so that it can generate the required data before it can be used via systemd. The script will now start it: wait for the service to come online and use the Integrations page to check for the connection state. Once the connection is successful, press CTRL+C to quit. Do you want to continue? (Y/N): " response

if [[ "$response" =~ ^[Yy]$ ]]; then
  echo "Starting Alloy service..."
  /usr/bin/alloy run $CUSTOM_ARGS --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy

  echo "You can now enable and start the Alloy service by running: systemctl enable alloy && systemctl start alloy"
else
  echo "Operation cancelled by user. You can run Alloy manually by using the run command defined in the systemd service file."
  exit 1
fi

else
  echo "Usage: $0 {install|configure}"
  exit 1
fi