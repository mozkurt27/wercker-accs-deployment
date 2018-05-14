#!/usr/bin/env bash

if [[ -z "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_REST_SERVER_URL" ]];
then
  echo 'Please specify  Oracle Container Cloud Service Console (manager node) url.'
  exit 1
fi

if [[ -z "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_OCCS_USER" ]];
then
  echo 'Please specify OCCS user'
  exit 1
fi

if [[ -z "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_OCCS_PASSWORD" ]];
then
  echo 'Please specify OCCS password'
  exit 1
fi

VALID_FUNCTIONS="start|stop|restart"

if ! echo "$VALID_FUNCTIONS" | grep -w "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_FUNCTION" > /dev/null; then
    echo "Please specify valid container function: $VALID_FUNCTIONS"
    exit 1
fi

if [[ -z "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DEPLOYMENT_NAME" && -z "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_SERVICE_ID" && -z "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DOCKER_IMAGE_NAME" ]];
then
  echo 'Please specify deployment name OR service id OR Docker image name.'
  exit 1
fi

# Get the token
curl_request_body=$(< <(cat <<EOF
{
  "username": "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_OCCS_USER",
  "password":"$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_OCCS_PASSWORD"
}
EOF
))

TOKEN=$(curl -sk "${WERCKER_ORACLE_OCCS_CONTAINER_UTIL_REST_SERVER_URL}/api/auth" -d "$curl_request_body" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["token"];')

if [ "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DEBUG" = "true" ];
then
    echo "token: $TOKEN"
fi

# Get the Bearer token

BEARER_TOKEN=$(curl -sk -H "Authorization: Session ${TOKEN}" "${WERCKER_ORACLE_OCCS_CONTAINER_UTIL_REST_SERVER_URL}/api/token" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["token"];')

if [ "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DEBUG" = "true" ];
then
    echo "bearer token:$BEARER_TOKEN"
fi

# Get container list
export CONTAINERS=$(curl -sk -X "GET" -H "Authorization: Bearer ${BEARER_TOKEN}" "${WERCKER_ORACLE_OCCS_CONTAINER_UTIL_REST_SERVER_URL}/api/v2/containers/")

if [ "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DEBUG" = "true" ];
then
    echo "==============================================="
    echo "$CONTAINERS"
    echo "==============================================="
fi

CONTAINER_ID=$(python - << EOF
import json,sys,os;

containers = json.loads(os.getenv('CONTAINERS'));

deploymentName = os.getenv('WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DEPLOYMENT_NAME');
serviceId = os.getenv('WERCKER_ORACLE_OCCS_CONTAINER_UTIL_SERVICE_ID');
dockerImage = os.getenv('WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DOCKER_IMAGE_NAME');

for i in range(len(containers['containers'])):
    if ((containers["containers"][i]["deployment_name"] == deploymentName) 
        or (containers["containers"][i]["service_id"] == serviceId)
        or (containers["containers"][i]["container"]["Config"]["Image"] == dockerImage)):   
        print containers['containers'][i]['container_id'];
        break;
EOF
)

if [ "$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_DEBUG" = "true" ];
then
    echo "container id:$CONTAINER_ID"
fi

if [ -n "$CONTAINER_ID" ];
then
    curl -sk -X "POST" -H "Authorization: Bearer ${BEARER_TOKEN}" "${WERCKER_ORACLE_OCCS_CONTAINER_UTIL_REST_SERVER_URL}/api/v2/containers/$CONTAINER_ID/$WERCKER_ORACLE_OCCS_CONTAINER_UTIL_FUNCTION"
fi
