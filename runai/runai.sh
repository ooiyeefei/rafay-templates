#!/bin/bash

#ROLE="ML engineer"

function create_user() {
  USER_ID=`curl -s -X GET "$RUNAI_URL/api/v1/users" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${TOKEN}" | ./jq -r '.[] | select(.username=="'"$USER"'") | .id'`

  if [ -z "${USER_ID}" ];
  then
    printf -- "\033[32m Info: User $USER not found \033[0m\n";
    printf -- "\033[32m Info: Creating user: $USER \033[0m\n";
    PASSWORD=`curl  -s -X POST "$RUNAI_URL/api/v1/users" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --data-raw '{
       "email": "'"$USER"'",
       "resetPassword": false
    }' | ./jq .tempPassword`
    PASSWORD=`sed -e 's/^"//' -e 's/"$//' <<<$PASSWORD`
    echo -n $PASSWORD > password
  else
    printf -- "\033[32m Info: Found user $USER - SUCCESS \033[0m\n";
    printf -- "\033[32m Info: User ID: $USER_ID \033[0m\n";
  fi
}

function create_cluster() {
  CLUSTER_ID=`curl -s -X GET "$RUNAI_URL/api/v1/clusters" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${TOKEN}" | ./jq -r '.[] | select(.name=="'"$CLUSTER"'") | .uuid'`

  if [ -z "${CLUSTER_ID}" ];
  then
    printf -- "\033[32m Info: Creating Cluster: $CLUSTER \033[0m\n";
    CLUSTER_ID=`curl  -s -X POST "$RUNAI_URL/api/v1/clusters" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer $TOKEN" \
      --data-raw '{
       "name": "'"$CLUSTER"'"
    }' | ./jq .uuid`
    CLUSTER_ID=`sed -e 's/^"//' -e 's/"$//' <<<$CLUSTER_ID`
    echo -n $CLUSTER_ID > uuid
    sleep 10
  else
    printf -- "\033[32m Info: Cluster ID: $CLUSTER_ID \033[0m\n";
    echo -n $CLUSTER_ID > uuid
  fi
  
  ROLE_ID=`curl -s -X GET "$RUNAI_URL/api/v1/authorization/roles" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer $TOKEN" | ./jq -r '.[] | select(.name=="'"$ROLE"'") | .id'`
  curl  -X POST  "$RUNAI_URL/api/v1/authorization/access-rules" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer $TOKEN" \
      --data-raw '{
        "subjectId": "'"$USER"'",
        "subjectType": "user",
        "roleId": '$ROLE_ID',
        "scopeId": "'"$CLUSTER_ID"'",
        "scopeType": "cluster"
       }'
}

##GET Authentication Token
TOKEN=`curl -s -X POST \
    "$RUNAI_URL/api/v1/token" \
    --header "Accept: */*" \
    --header "Content-Type: application/json" \
    --data-raw '{
    "grantType": "app_token",
    "AppId": "'"$APP"'",
    "AppSecret" : "'"$SECRET"'"
}' | ./jq .accessToken`

if [ -z "${TOKEN}" ];
then
  printf -- "\033[31m ERROR: Failed to token for $APP - FAILED \033[0m\n";
  exit 1
else
  TOKEN=`sed -e 's/^"//' -e 's/"$//' <<<"$TOKEN"`
  create_user
  create_cluster
fi
