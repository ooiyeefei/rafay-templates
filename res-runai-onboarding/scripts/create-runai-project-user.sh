#!/bin/bash
#
# Create Run:AI project and user with dedicated access
#
# Required environment variables:
#   RUNAI_CONTROL_PLANE_URL - Run:AI Control Plane URL
#   RUNAI_APP_ID            - Application ID for authentication
#   RUNAI_APP_SECRET        - Application secret for authentication
#   CLUSTER_UUID            - Cluster UUID (from create-runai-cluster.sh)
#   PROJECT_NAME            - Name for the project
#   USER_EMAIL              - Email for the user
#   USER_ROLE               - Role name (default: "ML engineer")

set -e

# Colors for output
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

printf "${GREEN}=== Run:AI Project & User Creation ===${NC}\n"

# Debug: Show environment variables
printf "${YELLOW}DEBUG: Environment check...${NC}\n"
printf "  RUNAI_CONTROL_PLANE_URL: ${RUNAI_CONTROL_PLANE_URL:-NOT SET}\n"
printf "  RUNAI_APP_ID: ${RUNAI_APP_ID:-NOT SET}\n"
printf "  RUNAI_APP_SECRET: ${RUNAI_APP_SECRET:+SET (hidden)}\n"
printf "  CLUSTER_UUID: ${CLUSTER_UUID:-NOT SET}\n"
printf "  PROJECT_NAME: ${PROJECT_NAME:-NOT SET}\n"
printf "  USER_EMAIL: ${USER_EMAIL:-NOT SET}\n"
printf "  USER_ROLE: ${USER_ROLE:-ML engineer}\n\n"

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

if [ -z "${PROJECT_NAME}" ]; then
  printf "${RED}ERROR: PROJECT_NAME not set${NC}\n"
  exit 1
fi

if [ -z "${USER_EMAIL}" ]; then
  printf "${RED}ERROR: USER_EMAIL not set${NC}\n"
  exit 1
fi

# Default role if not set
USER_ROLE="${USER_ROLE:-ML engineer}"

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
printf "  Project Name: ${PROJECT_NAME}\n"
printf "  User Email: ${USER_EMAIL}\n"
printf "  User Role: ${USER_ROLE}\n\n"

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

# Step 2: Create Project
printf "${GREEN}Step 2: Creating project '${PROJECT_NAME}' in cluster...${NC}\n"

# Check if project already exists
EXISTING_PROJECT_ID=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Authorization: Bearer ${TOKEN}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/k8s/clusters/${CLUSTER_UUID}/projects" | \
  ${JQ} -r ".[] | select(.name==\"${PROJECT_NAME}\") | .id")

if [ -n "${EXISTING_PROJECT_ID}" ] && [ "${EXISTING_PROJECT_ID}" != "null" ]; then
  printf "${YELLOW}Project already exists with ID: ${EXISTING_PROJECT_ID}${NC}\n"
  PROJECT_ID="${EXISTING_PROJECT_ID}"
else
  # Create project
  PROJECT_RESPONSE=$(wget -q -O- \
    --header="Accept: application/json" \
    --header="Content-Type: application/json" \
    --header="Authorization: Bearer ${TOKEN}" \
    --post-data="{\"name\":\"${PROJECT_NAME}\",\"clusterId\":\"${CLUSTER_UUID}\"}" \
    "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/k8s/clusters/${CLUSTER_UUID}/projects")

  printf "${YELLOW}DEBUG: Project creation response:${NC}\n${PROJECT_RESPONSE}\n\n"

  PROJECT_ID=$(echo "${PROJECT_RESPONSE}" | ${JQ} -r '.id')

  if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" == "null" ]; then
    printf "${RED}ERROR: Failed to create project${NC}\n"
    printf "${RED}Response: ${PROJECT_RESPONSE}${NC}\n"
    exit 1
  fi

  printf "${GREEN}✓ Project created with ID: ${PROJECT_ID}${NC}\n"
fi

# Save project ID
echo -n "${PROJECT_ID}" > project_id.txt

printf "\n"

# Step 3: Create User (Local User with Password)
printf "${GREEN}Step 3: Creating user '${USER_EMAIL}'...${NC}\n"

# Check if user already exists
EXISTING_USER_ID=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Authorization: Bearer ${TOKEN}" \
  "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/users" | \
  ${JQ} -r ".[] | select(.email==\"${USER_EMAIL}\") | .id")

if [ -n "${EXISTING_USER_ID}" ] && [ "${EXISTING_USER_ID}" != "null" ]; then
  printf "${YELLOW}User already exists with ID: ${EXISTING_USER_ID}${NC}\n"
  USER_ID="${EXISTING_USER_ID}"
  USER_PASSWORD=""  # Cannot retrieve existing password
else
  # Create user (local user with resetPassword: false to get temp password)
  USER_RESPONSE=$(wget -q -O- \
    --header="Accept: application/json" \
    --header="Content-Type: application/json" \
    --header="Authorization: Bearer ${TOKEN}" \
    --post-data="{\"email\":\"${USER_EMAIL}\",\"resetPassword\":false}" \
    "https://${RUNAI_CONTROL_PLANE_URL}/api/v1/users")

  printf "${YELLOW}DEBUG: User creation response:${NC}\n${USER_RESPONSE}\n\n"

  USER_ID=$(echo "${USER_RESPONSE}" | ${JQ} -r '.id')
  USER_PASSWORD=$(echo "${USER_RESPONSE}" | ${JQ} -r '.tempPassword // empty')

  if [ -z "${USER_ID}" ] || [ "${USER_ID}" == "null" ]; then
    printf "${RED}ERROR: Failed to create user${NC}\n"
    printf "${RED}Response: ${USER_RESPONSE}${NC}\n"
    exit 1
  fi

  printf "${GREEN}✓ User created with ID: ${USER_ID}${NC}\n"
  if [ -n "${USER_PASSWORD}" ]; then
    printf "${GREEN}✓ Temporary password generated${NC}\n"
  fi
fi

# Save user email and password
echo -n "${USER_EMAIL}" > user_email.txt
if [ -n "${USER_PASSWORD}" ]; then
  echo -n "${USER_PASSWORD}" > user_password.txt
else
  # User already existed, create placeholder
  echo -n "existing-user-no-password-available" > user_password.txt
fi

printf "\n"

# Step 4: Get Role ID for the specified role
printf "${GREEN}Step 4: Finding role '${USER_ROLE}'...${NC}\n"

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

# Step 5: Create Access Rule - Scope to Project (not entire cluster)
printf "${GREEN}Step 5: Creating access rule (user -> project scope)...${NC}\n"

# According to API docs: subjectId is the user email, scopeId is the project ID
ACCESS_RULE_RESPONSE=$(wget -q -O- \
  --header="Accept: application/json" \
  --header="Content-Type: application/json" \
  --header="Authorization: Bearer ${TOKEN}" \
  --post-data="{\"subjectId\":\"${USER_EMAIL}\",\"subjectType\":\"user\",\"roleId\":${ROLE_ID},\"scopeId\":\"${PROJECT_ID}\",\"scopeType\":\"project\"}" \
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
printf "Project Name: ${PROJECT_NAME}\n"
printf "Project ID: ${PROJECT_ID}\n"
printf "User Email: ${USER_EMAIL}\n"
printf "User ID: ${USER_ID}\n"
if [ -n "${USER_PASSWORD}" ]; then
  printf "User Password: ********** (saved to user_password.txt)\n"
else
  printf "User Password: N/A (user already existed)\n"
fi
printf "User Role: ${USER_ROLE}\n"
printf "Access Scope: Project '${PROJECT_NAME}' (not entire cluster)\n"
printf "${GREEN}================================${NC}\n"

exit 0
