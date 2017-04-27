#!/bin/bash

set -o pipefail

POD_NAMESPACE=${POD_NAMESPACE:-default}
POD_IP=${POD_IP:-127.0.0.1}
RETHINK_CLUSTER=${RETHINK_CLUSTER:-"rethinkdb"}
POD_NAME=${POD_NAME:-"NO_POD_NAME"}

# comma separated server tag list
SERVER_TAGS=${SERVER_TAGS:-""}
SERVER_TAGS_STR=`echo $SERVER_TAGS|awk -F, '{for(i=1;i<=NF;++i) printf("--server-tag %s ",$i)}'`

# Transform - to _ to comply with requirements
SERVER_NAME=$(echo ${POD_NAME} | sed 's/-/_/g')

echo "Using additional CLI flags: ${@}"
echo "Pod IP: ${POD_IP}"
echo "Pod namespace: ${POD_NAMESPACE}"
echo "Using service name: ${RETHINK_CLUSTER}"
echo "Using server name: ${SERVER_NAME}"

echo "Checking for other nodes..."
if [[ -n "${KUBERNETES_SERVICE_HOST}" && -z "${USE_SERVICE_LOOKUP}" ]]; then
  echo "Using endpoints to lookup other nodes..."
  URL="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/namespaces/${POD_NAMESPACE}/endpoints/${RETHINK_CLUSTER}"
  echo "Endpoint url: ${URL}"
  echo "Looking for IPs..."
  token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  # try to pick up first different ip from endpoints
  IP=$(curl -s ${URL} --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt --header "Authorization: Bearer ${token}" \
    | jq -s -r --arg h "${POD_IP}" '.[0].subsets | .[].addresses | [ .[].ip ] | map(select(. != $h)) | .[0]') || exit 1
  [[ "${IP}" == null ]] && IP=""
  JOIN_ENDPOINTS="${IP}"
else
  echo "Using service to lookup other nodes..."
  # We can just use ${RETHINK_CLUSTER} due to dns lookup
  # Instead though, let's be explicit:
  JOIN_ENDPOINTS=$(getent hosts "${RETHINK_CLUSTER}.${POD_NAMESPACE}.svc.cluster.local" | awk '{print $1}')

  # Let's filter out our IP address if it's in there...
  JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | sed -e "s/${POD_IP}//g")
fi

# xargs echo removes extra spaces before/after
# tr removes extra spaces in the middle
JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | xargs echo | tr -s ' ')

if [ -n "${JOIN_ENDPOINTS}" ]; then
  echo "Found other nodes: ${JOIN_ENDPOINTS}"

  # Now, transform join endpoints into --join ENDPOINT:29015
  # Put port after each
  JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | sed -r 's/([0-9.])+/&:29015/g')

  # Put --join before each
  JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | sed -e 's/^\|[ ]/&--join /g')
else
  echo "No other nodes detected, will be a single instance."
  if [ -n "$PROXY" ]; then
    echo "Cannot start in proxy mode without endpoints."
    exit 1
  fi
fi

if [[ -n "${PROXY}" ]]; then
  echo "Starting in proxy mode"
  set -x
  exec rethinkdb \
    proxy \
    --canonical-address ${POD_IP} \
    --bind all \
    ${JOIN_ENDPOINTS} \
    ${@}
else
  set -x
  exec rethinkdb \
    --server-name ${SERVER_NAME} \
    --canonical-address ${POD_IP} \
    --bind all \
    ${JOIN_ENDPOINTS} \
    ${SERVER_TAGS_STR} \
    ${@}
fi
