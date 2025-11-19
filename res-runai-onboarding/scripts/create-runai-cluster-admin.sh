#!/bin/bash
#
# Create Run:AI cluster administrator user
#
# Required environment variables:
#   RUNAI_CONTROL_PLANE_URL - Run:AI Control Plane URL
#   RUNAI_APP_ID            - Application ID for authentication
#   RUNAI_APP_SECRET        - Application secret for authentication
#   CLUSTER_UUID            - Cluster UUID (from create-runai-cluster.sh)
#   USER_EMAIL              - Email for the user
#
# User will be assigned "Administrator" role with cluster-scoped access
# This means the user can:
#   - See and manage ALL projects in this cluster
#   - Manage cluster settings, add users, configure resources
#   - CANNOT see other clusters in the organization
#

set -e

# Colors for output
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

printf "${GREEN}=== Run:AI Cluster Administrator Creation ===${NC}\n"

# Debug: Show environment variables
printf "${YELLOW}DEBUG: Environment check...${NC}\n"
printf "  RUNAI_CONTROL_PLANE_URL: ${RUNAI_CONTROL_PLANE_URL:-NOT SET}\n"
printf "  RUNAI_APP_ID: ${RUNAI_APP_ID:-NOT SET}\n"
printf "  RUNAI_APP_SECRET: ${RUNAI_APP_SECRET:+SET (hidden)}\n"
printf "  CLUSTER_UUID: ${CLUSTER_UUID:-NOT SET}\n"
printf "  USER_EMAIL: ${USER_EMAIL:-NOT SET}\n\n"

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

if [ -z "${CLUSTER_UUID}" ]; then
  printf "${RED}ERROR: CLUSTER_UUID not set${NC}\n"
  exit 1
fi

if [ -z "${USER_EMAIL}" ]; then
  printf "${RED}ERROR: USER_EMAIL not set${NC}\n"
  exit 1
fi

# Always use Administrator role for cluster-scoped access
USER_ROLE="Administrator"

# Use locally downloaded jq binary
JQ="./jq"
if [ ! -f "${JQ}" ]; then
  printf "${RED}ERROR: jq binary not found at ${JQ}${NC}\n"
  printf "${RED}Run setup.sh first to download required tools${NC}\n"
  exit 1
fi

printf "${GREEN}Configuration:${NC}\n"
printf "  Control Plane: ${RUNAI_CONTROL_PLANE_URL}\n"
printf "  Cluster UUID: ${CLUSTER_UUID}\n"
printf "  User Email: ${USER_EMAIL}\n"
printf "  User Role: ${USER_ROLE} (cluster-scoped)\n\n"

# Step 1: Get authentication token
printf "${GREEN}Step 1: Authenticating with Run:AI Control Plane...${NC}\n"

TOKEN=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Content-Type: application/json" \
  --post-data="{\"grantType\":\"client_credentials\",\"clientId\":\"${RUNAI_APP_ID}\",\"clientSecret\":\"${RUNAI_APP_SECRET}\"}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/token" | ${JQ} -r '.accessToken')

if [ -z "${TOKEN}" ] || [ "${TOKEN}" == "null" ]; then
  printf "${RED}ERROR: Failed to authenticate with Run:AI Control Plane${NC}\n"
  exit 1
fi

printf "${GREEN}✓ Authentication successful${NC}\n\n"

# Step 2: Create User (Local User with Run:AI generated temp password)
printf "${GREEN}Step 2: Creating user '${USER_EMAIL}'...${NC}\n"

# Check if user already exists
EXISTING_USER_RESPONSE=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Authorization: Bearer ${TOKEN}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/users")

printf "${YELLOW}DEBUG: Users list response (first 500 chars):${NC}\n${EXISTING_USER_RESPONSE:0:500}\n\n"

EXISTING_USER_ID=$(echo "${EXISTING_USER_RESPONSE}" | ${JQ} -r ".[] | select(.username==\"${USER_EMAIL}\") | .id")

if [ -n "${EXISTING_USER_ID}" ] && [ "${EXISTING_USER_ID}" != "null" ]; then
  printf "${YELLOW}User already exists with ID: ${EXISTING_USER_ID}${NC}\n"
  printf "${YELLOW}Note: Use Run:AI UI to reset password if needed.${NC}\n"
  USER_ID="${EXISTING_USER_ID}"
  # Save empty password to indicate existing user
  echo -n "" > user_password.txt
else
  # Create user with resetPassword: false to get temp password
  # Use --server-response to capture HTTP status code
  USER_RESPONSE=$(wget --server-response --content-on-error -q -O- \
    --header="Accept: application/json" \
    --header="Content-Type: application/json" \
    --header="Authorization: Bearer ${TOKEN}" \
    --post-data="{\"email\":\"${USER_EMAIL}\",\"resetPassword\":false}" \
    "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/users" 2>&1)

  printf "${YELLOW}DEBUG: User creation response:${NC}\n${USER_RESPONSE}\n\n"

  # Check if we got 409 Conflict (user already exists)
  if echo "${USER_RESPONSE}" | grep -q "409 Conflict"; then
    printf "${YELLOW}User already exists (409 Conflict). Fetching user ID...${NC}\n"
    # Re-fetch to get user ID
    EXISTING_USER_RESPONSE=$(wget -q -O- \
      --header="Accept: application/json" \
      --header="Authorization: Bearer ${TOKEN}" \
      "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/users")
    USER_ID=$(echo "${EXISTING_USER_RESPONSE}" | ${JQ} -r ".[] | select(.username==\"${USER_EMAIL}\") | .id")
    # Save empty password to indicate existing user
    echo -n "" > user_password.txt
    printf "${GREEN}✓ Found existing user with ID: ${USER_ID}${NC}\n"
  else
    # Extract JSON body (after blank line)
    USER_JSON=$(echo "${USER_RESPONSE}" | sed -n '/^$/,${/^$/d;p}')
    USER_ID=$(echo "${USER_JSON}" | ${JQ} -r '.id')
    GENERATED_PASSWORD=$(echo "${USER_JSON}" | ${JQ} -r '.tempPassword // empty')

    if [ -z "${USER_ID}" ] || [ "${USER_ID}" == "null" ]; then
      printf "${RED}ERROR: Failed to create user${NC}\n"
      printf "${RED}Response: ${USER_RESPONSE}${NC}\n"
      exit 1
    fi

    printf "${GREEN}✓ User created with ID: ${USER_ID}${NC}\n"

    if [ -n "${GENERATED_PASSWORD}" ]; then
      # Save the generated password to file for Terraform to read
      echo -n "${GENERATED_PASSWORD}" > user_password.txt
      printf "${GREEN}✓ Temporary password generated (will be available in Terraform outputs)${NC}\n"
    fi
  fi
fi

printf "\n"

# Step 3: Get Role ID for Administrator role
printf "${GREEN}Step 3: Finding role '${USER_ROLE}'...${NC}\n"

ROLE_ID=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Authorization: Bearer ${TOKEN}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/authorization/roles" | \
  ${JQ} -r ".[] | select(.name==\"${USER_ROLE}\") | .id")

if [ -z "${ROLE_ID}" ] || [ "${ROLE_ID}" == "null" ]; then
  printf "${RED}ERROR: Role '${USER_ROLE}' not found${NC}\n"
  printf "${RED}Available roles:${NC}\n"
  wget -q -O- \
    --header="Accept: application/json" \
    --header="Authorization: Bearer ${TOKEN}" \
    "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/authorization/roles" | \
    ${JQ} -r '.[].name'
  exit 1
fi

printf "${GREEN}✓ Found role with ID: ${ROLE_ID}${NC}\n\n"

# Step 4: Create Access Rule - Cluster-scoped Administrator
printf "${GREEN}Step 4: Creating access rule (user -> cluster admin)...${NC}\n"

# Cluster-scoped access: user can manage entire cluster but not see other clusters
# According to API docs: https://rafay.runailabs-ps.com/api/docs#tag/Access-rules/operation/create_access_rule
# Required fields:
#   - subjectId: user email
#   - subjectType: "user"
#   - roleId: Administrator role ID
#   - scopeId: cluster UUID
#   - scopeType: "cluster"
#   - clusterId: cluster UUID (ALSO REQUIRED for cluster-scoped access!)
ACCESS_RULE_RESPONSE=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Content-Type: application/json" \
  --header="Authorization: Bearer ${TOKEN}" \
  --post-data="{\"subjectId\":\"${USER_EMAIL}\",\"subjectType\":\"user\",\"roleId\":${ROLE_ID},\"scopeId\":\"${CLUSTER_UUID}\",\"scopeType\":\"cluster\",\"clusterId\":\"${CLUSTER_UUID}\"}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/authorization/access-rules")

printf "${YELLOW}DEBUG: Access rule creation response:${NC}\n${ACCESS_RULE_RESPONSE}\n\n"

ACCESS_RULE_ID=$(echo "${ACCESS_RULE_RESPONSE}" | ${JQ} -r '.id // empty')

if [ -n "${ACCESS_RULE_ID}" ] && [ "${ACCESS_RULE_ID}" != "null" ]; then
  printf "${GREEN}✓ Access rule created with ID: ${ACCESS_RULE_ID}${NC}\n"
else
  # Check if access rule already exists (API returns error if duplicate)
  printf "${YELLOW}Warning: Access rule may already exist or creation failed${NC}\n"
  printf "${YELLOW}Response: ${ACCESS_RULE_RESPONSE}${NC}\n"
fi

printf "\n${GREEN}=== Summary ===${NC}\n"
printf "User Email: ${USER_EMAIL}\n"
printf "User ID: ${USER_ID}\n"
printf "User Password: ********** (available in Terraform outputs - marked as sensitive)\n"
printf "User Role: ${USER_ROLE}\n"
printf "Access Scope: Cluster-scoped (can manage this cluster only, cannot see other clusters)\n"
printf "Control Plane URL: https://${RUNAI_CONTROL_PLANE_URL}\n"
printf "${GREEN}================================${NC}\n"

exit 0
