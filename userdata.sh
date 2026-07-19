#!/bin/bash
set -e

# Update packages
yum update -y

# Install required tools
yum install -y wget unzip jq

# Region
REGION="us-east-1"

# Dynatrace Environment
DT_ENV="https://aav98370.live.dynatrace.com"

# Secret Name
SECRET_NAME="dynatrace-paas-token"

# Read Installer Token from Secrets Manager
TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id ${SECRET_NAME} \
  --region ${REGION} \
  --query SecretString \
  --output text)

# Download OneAgent
wget -O Dynatrace-OneAgent.sh \
"${DT_ENV}/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=${TOKEN}"

chmod +x Dynatrace-OneAgent.sh

# Install OneAgent
./Dynatrace-OneAgent.sh

echo "Dynatrace OneAgent installation completed."