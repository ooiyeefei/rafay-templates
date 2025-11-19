#!/bin/bash
#
# Delete Run:AI cluster from Control Plane during terraform destroy
#
# Required environment variables:
#   RUNAI_CONTROL_PLANE_URL - Run:AI Control Plane URL
#   RUNAI_APP_ID            - Application ID for authentication
#   RUNAI_APP_SECRET        - Application secret for authentication
#   CLUSTER_UUID            - UUID of the cluster to delete

set -e

# Colors for output
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

printf "${GREEN}=== Run:AI Cluster Deletion ===${NC}\n"

# Debug: Show all environment variables (mask secret)
printf "${YELLOW}DEBUG: Environment check...${NC}\n"
printf "  RUNAI_CONTROL_PLANE_URL: ${RUNAI_CONTROL_PLANE_URL:-NOT SET}\n"
printf "  RUNAI_APP_ID: ${RUNAI_APP_ID:-NOT SET}\n"
printf "  RUNAI_APP_SECRET: ${RUNAI_APP_SECRET:+SET (hidden)}\n"
printf "  CLUSTER_UUID: ${CLUSTER_UUID:-NOT SET}\n\n"

# Validate required environment variables
if [ -z "${RUNAI_CONTROL_PLANE_URL}" ]; then
  printf "${YELLOW}WARNING: RUNAI_CONTROL_PLANE_URL not set, skipping cleanup${NC}\n"
  exit 0
fi

if [ -z "${RUNAI_APP_ID}" ]; then
  printf "${YELLOW}WARNING: RUNAI_APP_ID not set, skipping cleanup${NC}\n"
  exit 0
fi

if [ -z "${RUNAI_APP_SECRET}" ]; then
  printf "${YELLOW}WARNING: RUNAI_APP_SECRET not set, skipping cleanup${NC}\n"
  exit 0
fi

if [ -z "${CLUSTER_UUID}" ]; then
  printf "${YELLOW}WARNING: CLUSTER_UUID not set, skipping cleanup${NC}\n"
  exit 0
fi

# Use locally downloaded jq binary (downloaded by setup.sh)
JQ="./jq"
if [ ! -f "${JQ}" ]; then
  printf "${RED}ERROR: jq binary not found at ${JQ}${NC}\n"
  printf "${YELLOW}Attempting cleanup without jq (less robust)${NC}\n"
  JQ="jq"  # Try system jq
fi

printf "${GREEN}Configuration:${NC}\n"
printf "  Control Plane: ${RUNAI_CONTROL_PLANE_URL}\n"
printf "  App ID: ${RUNAI_APP_ID}\n"
printf "  Cluster UUID: ${CLUSTER_UUID}\n\n"

# Step 1: Get authentication token
printf "${GREEN}Step 1: Authenticating with Run:AI Control Plane...${NC}\n"

TOKEN_RESPONSE=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Content-Type: application/json" \
  --post-data="{\"grantType\":\"client_credentials\",\"clientId\":\"${RUNAI_APP_ID}\",\"clientSecret\":\"${RUNAI_APP_SECRET}\"}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/token" 2>&1 || echo "")

if [ -z "${TOKEN_RESPONSE}" ]; then
  printf "${YELLOW}WARNING: Failed to get token response, skipping cleanup${NC}\n"
  exit 0
fi

TOKEN=$(echo "${TOKEN_RESPONSE}" | ${JQ} -r '.accessToken' 2>/dev/null || echo "")

if [ -z "${TOKEN}" ] || [ "${TOKEN}" == "null" ]; then
  printf "${YELLOW}WARNING: Failed to authenticate, skipping cleanup${NC}\n"
  printf "${YELLOW}This is OK - cluster may have been already deleted manually${NC}\n"
  exit 0
fi

printf "${GREEN}✓ Authentication successful${NC}\n\n"

# Step 2: Delete user (if USER_ID provided)
if [ -n "${USER_ID}" ] && [ "${USER_ID}" != "null" ]; then
  printf "${GREEN}Step 2: Deleting user ${USER_ID}...${NC}\n"

  # Check if curl is available (better for DELETE requests than BusyBox wget)
  if command -v curl >/dev/null 2>&1; then
    # Use curl for DELETE - following pattern from test-cluster-response.sh
    set +e
    USER_DELETE_RESPONSE=$(curl -s -X DELETE \
      "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/users/${USER_ID}" \
      --header "Accept: application/json" \
      --header "Authorization: Bearer ${TOKEN}" 2>&1)
    USER_DELETE_EXIT=$?
    set -e

    printf "${YELLOW}DEBUG: User delete response:${NC}\n${USER_DELETE_RESPONSE}\n\n"

    # Success if curl succeeded or response is empty (204 No Content)
    if [ ${USER_DELETE_EXIT} -eq 0 ]; then
      printf "${GREEN}✓ User deleted successfully${NC}\n\n"
    else
      printf "${YELLOW}WARNING: User deletion may have failed (non-critical)${NC}\n\n"
    fi
  else
    # Fallback: Skip user deletion if curl not available
    printf "${YELLOW}WARNING: curl not available, skipping user deletion${NC}\n"
    printf "${YELLOW}User ${USER_EMAIL} (ID: ${USER_ID}) must be deleted manually in Run:AI UI${NC}\n\n"
  fi
else
  printf "${YELLOW}Step 2: Skipping user deletion (no USER_ID provided)${NC}\n\n"
fi

# Step 3: Delete cluster with force=true
printf "${GREEN}Step 3: Deleting cluster ${CLUSTER_UUID}...${NC}\n"

# Check if curl is available (better for DELETE requests than BusyBox wget)
if command -v curl >/dev/null 2>&1; then
  # Use curl for DELETE - following pattern from test-cluster-response.sh
  set +e
  CLUSTER_DELETE_RESPONSE=$(curl -s -X DELETE \
    "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/clusters/${CLUSTER_UUID}?force=true" \
    --header "Accept: application/json" \
    --header "Authorization: Bearer ${TOKEN}" 2>&1)
  CLUSTER_DELETE_EXIT=$?
  set -e

  printf "${YELLOW}DEBUG: Cluster delete response:${NC}\n${CLUSTER_DELETE_RESPONSE}\n\n"

  # Success if curl succeeded or response is empty (204 No Content)
  if [ ${CLUSTER_DELETE_EXIT} -eq 0 ]; then
    printf "${GREEN}✓ Cluster deletion initiated or already removed${NC}\n"
  else
    printf "${YELLOW}WARNING: Cluster deletion may have failed (non-critical)${NC}\n"
  fi
else
  # Fallback: Skip cluster deletion if curl not available
  printf "${YELLOW}WARNING: curl not available, skipping cluster deletion${NC}\n"
  printf "${YELLOW}Cluster ${CLUSTER_UUID} must be deleted manually in Run:AI UI${NC}\n"
fi

printf "${GREEN}Terraform resources will now be destroyed${NC}\n"
printf "${GREEN}==================================${NC}\n"

exit 0
