#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package list and install curl
echo "Installing curl..."
sudo apt-get update
sudo apt-get install -y curl

# Add Ookla Speedtest repository
echo "Adding Ookla Speedtest repository..."
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash

# Install Speedtest CLI
echo "Installing Speedtest CLI..."
sudo apt-get install -y speedtest

# Confirm installation
echo "Speedtest CLI installed successfully."
speedtest --version
