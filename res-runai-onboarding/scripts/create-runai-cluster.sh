#!/bin/bash
#
# Create Run:AI cluster in Control Plane and retrieve client secret
#
# Required environment variables:
#   RUNAI_CONTROL_PLANE_URL - Run:AI Control Plane URL
#   RUNAI_APP_ID            - Application ID for authentication
#   RUNAI_APP_SECRET        - Application secret for authentication
#   CLUSTER_NAME            - Name for the cluster
#   CLUSTER_FQDN            - Fully qualified domain name for the cluster

set -e

# Colors for output
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

printf "${GREEN}=== Run:AI Cluster Creation ===${NC}\n"

# Validate required environment variables
if [ -z "${RUNAI_CONTROL_PLANE_URL}" ]; then
  printf "${RED}ERROR: RUNAI_CONTROL_PLANE_URL not set${NC}\n"
  exit 1
fi

if [ -z "${RUNAI_APP_ID}" ]; then
  printf "${RED}ERROR: RUNAI_APP_ID not set${NC}\n"
  exit 1
fi

if [ -z "${RUNAI_APP_SECRET}" ]; then
  printf "${RED}ERROR: RUNAI_APP_SECRET not set${NC}\n"
  exit 1
fi

if [ -z "${CLUSTER_NAME}" ]; then
  printf "${RED}ERROR: CLUSTER_NAME not set${NC}\n"
  exit 1
fi

if [ -z "${CLUSTER_FQDN}" ]; then
  printf "${RED}ERROR: CLUSTER_FQDN not set${NC}\n"
  exit 1
fi

# Use locally downloaded jq binary (downloaded by setup.sh)
JQ="./jq"
if [ ! -f "${JQ}" ]; then
  printf "${RED}ERROR: jq binary not found at ${JQ}${NC}\n"
  printf "${RED}Run setup.sh first to download required tools${NC}\n"
  exit 1
fi

printf "${GREEN}Configuration:${NC}\n"
printf "  Control Plane: ${RUNAI_CONTROL_PLANE_URL}\n"
printf "  App ID: ${RUNAI_APP_ID}\n"
printf "  Cluster Name: ${CLUSTER_NAME}\n"
printf "  Cluster FQDN: ${CLUSTER_FQDN}\n\n"

# Step 1: Get authentication token
printf "${GREEN}Step 1: Authenticating with Run:AI Control Plane...${NC}\n"

TOKEN=$(curl -s -X POST "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/token" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"grantType\": \"app_token\",
    \"AppId\": \"${RUNAI_APP_ID}\",
    \"AppSecret\": \"${RUNAI_APP_SECRET}\"
  }" | ${JQ} -r '.accessToken')

if [ -z "${TOKEN}" ] || [ "${TOKEN}" == "null" ]; then
  printf "${RED}ERROR: Failed to authenticate with Run:AI Control Plane${NC}\n"
  exit 1
fi

printf "${GREEN}✓ Authentication successful${NC}\n\n"

# Step 2: Check if cluster already exists
printf "${GREEN}Step 2: Checking if cluster '${CLUSTER_NAME}' exists...${NC}\n"

EXISTING_CLUSTER_UUID=$(curl -s -X GET "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/clusters" \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${TOKEN}" | \
  ${JQ} -r ".[] | select(.name==\"${CLUSTER_NAME}\") | .uuid")

if [ -n "${EXISTING_CLUSTER_UUID}" ] && [ "${EXISTING_CLUSTER_UUID}" != "null" ]; then
  printf "${YELLOW}Cluster already exists with UUID: ${EXISTING_CLUSTER_UUID}${NC}\n"
  CLUSTER_UUID="${EXISTING_CLUSTER_UUID}"
else
  # Step 3: Create cluster
  printf "${GREEN}Step 3: Creating cluster '${CLUSTER_NAME}'...${NC}\n"

  CREATE_RESPONSE=$(curl -s -X POST "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/clusters" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${TOKEN}" \
    --data-raw "{
      \"name\": \"${CLUSTER_NAME}\",
      \"domain\": \"https://${CLUSTER_FQDN}\"
    }")

  CLUSTER_UUID=$(echo "${CREATE_RESPONSE}" | ${JQ} -r '.uuid')

  if [ -z "${CLUSTER_UUID}" ] || [ "${CLUSTER_UUID}" == "null" ]; then
    printf "${RED}ERROR: Failed to create cluster${NC}\n"
    printf "${RED}Response: ${CREATE_RESPONSE}${NC}\n"
    exit 1
  fi

  printf "${GREEN}✓ Cluster created with UUID: ${CLUSTER_UUID}${NC}\n"
fi

# Save cluster UUID to file
echo -n "${CLUSTER_UUID}" > cluster_uuid.txt

printf "\n"

# Step 4: Get cluster installation info (including client secret)
printf "${GREEN}Step 4: Retrieving cluster installation info...${NC}\n"

INSTALL_INFO=$(curl -s -X GET "https://${RUNAI_CONTROL_PLANE_URL}/v1/clusters/${CLUSTER_UUID}/cluster-install-info" \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${TOKEN}")

CLIENT_SECRET=$(echo "${INSTALL_INFO}" | ${JQ} -r '.clientSecret')

if [ -z "${CLIENT_SECRET}" ] || [ "${CLIENT_SECRET}" == "null" ]; then
  printf "${RED}ERROR: Failed to retrieve client secret${NC}\n"
  printf "${RED}Response: ${INSTALL_INFO}${NC}\n"
  exit 1
fi

printf "${GREEN}✓ Client secret retrieved successfully${NC}\n"

# Save outputs to files for Terraform to read
echo -n "${CLIENT_SECRET}" > client_secret.txt
echo -n "${RUNAI_CONTROL_PLANE_URL}" > control_plane_url.txt

# Optional: Extract other useful info
INSTALLATION_STR=$(echo "${INSTALL_INFO}" | ${JQ} -r '.installationStr // empty')
CHART_REPO_URL=$(echo "${INSTALL_INFO}" | ${JQ} -r '.chartRepoURL // empty')
REPOSITORY_NAME=$(echo "${INSTALL_INFO}" | ${JQ} -r '.repositoryName // empty')

if [ -n "${INSTALLATION_STR}" ]; then
  printf "\n${GREEN}Installation string:${NC}\n${INSTALLATION_STR}\n"
fi

printf "\n${GREEN}=== Summary ===${NC}\n"
printf "Cluster UUID: ${CLUSTER_UUID}\n"
printf "Client Secret: ********** (saved to client_secret.txt)\n"
if [ -n "${CHART_REPO_URL}" ]; then
  printf "Helm Repo: ${CHART_REPO_URL}\n"
fi
if [ -n "${REPOSITORY_NAME}" ]; then
  printf "Repository: ${REPOSITORY_NAME}\n"
fi
printf "${GREEN}================================${NC}\n"

exit 0
